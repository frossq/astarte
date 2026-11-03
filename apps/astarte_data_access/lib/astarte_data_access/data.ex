#
# This file is part of Astarte.
#
# Copyright 2018 - 2025 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.DataAccess.Data do
  @moduledoc """
  This module provides functions to access data stored in the database, ensuring schema agreement when necessary.
  """

  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping
  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.Realms.IndividualProperty
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.Secrets
  alias Ecto.UUID

  import Ecto.Query

  require Logger

  @spec fetch_property(
          String.t(),
          Device.device_id(),
          InterfaceDescriptor.t(),
          Mapping.t(),
          String.t()
        ) :: {:ok, {any(), binary() | nil}} | {:error, atom()}
  def fetch_property(
        realm,
        device_id,
        %InterfaceDescriptor{storage_type: :multi_interface_individual_properties_dbtable} =
          interface_descriptor,
        mapping,
        path
      )
      when is_binary(device_id) and is_binary(path) do
    keyspace = Realm.keyspace_name(realm)

    device_id = UUID.cast!(device_id)
    interface_id = UUID.cast!(interface_descriptor.interface_id)
    endpoint_id = UUID.cast!(mapping.endpoint_id)

    fetch_clause = fetch_clause(device_id, interface_id, endpoint_id, path)

    query =
      case mapping.encrypted do
        true ->
          from s in interface_descriptor.storage,
            prefix: ^keyspace,
            select: %{encrypted_value: s.encryptedblob_value, encrypted_dek: s.encrypted_dek}

        _ ->
          value_column =
            mapping.value_type
            |> CQLUtils.type_to_db_column_name()
            |> String.to_atom()

          from s in interface_descriptor.storage,
            prefix: ^keyspace,
            select: %{value: field(s, ^value_column)}
      end

    consistency = Consistency.device_info(:read)

    Repo.fetch_by(query, fetch_clause, consistency: consistency) |> normalize_fetch_result(realm)
  end

  @spec path_exists?(
          String.t(),
          Device.device_id(),
          InterfaceDescriptor.t(),
          Mapping.t(),
          String.t()
        ) :: {:ok, boolean} | {:error, atom}
  def path_exists?(
        realm,
        device_id,
        interface_descriptor,
        mapping,
        path
      )
      when is_binary(device_id) and is_binary(path) do
    keyspace = Realm.keyspace_name(realm)
    fetch_clause = fetch_clause(device_id, interface_descriptor, mapping, path)

    consistency = Consistency.domain_model(:read)

    from(IndividualProperty, prefix: ^keyspace, where: ^fetch_clause)
    |> Repo.aggregate(:count, consistency: consistency)
    |> case do
      0 -> {:ok, false}
      1 -> {:ok, true}
    end
  end

  @spec fetch_last_path_update(
          String.t(),
          Device.device_id(),
          InterfaceDescriptor.t(),
          Mapping.t(),
          String.t()
        ) ::
          {:ok, %{value_timestamp: DateTime.t(), reception_timestamp: DateTime.t()}}
          | {:error, atom}
  def fetch_last_path_update(
        realm,
        device_id,
        interface_descriptor,
        mapping,
        path
      )
      when is_binary(device_id) and is_binary(path) do
    keyspace = Realm.keyspace_name(realm)
    fetch_clause = fetch_clause(device_id, interface_descriptor, mapping, path)

    query =
      from IndividualProperty,
        prefix: ^keyspace,
        select: [:datetime_value, :reception_timestamp, :reception_timestamp_submillis]

    with {:ok, property} <- Repo.fetch_by(query, fetch_clause, error: :path_not_set) do
      value_timestamp = property.datetime_value |> DateTime.truncate(:millisecond)
      reception_timestamp = IndividualProperty.reception(property)

      {:ok, %{value_timestamp: value_timestamp, reception_timestamp: reception_timestamp}}
    end
  end

  defp fetch_clause(
         device_id,
         %{interface_id: interface_id} = _interface_descriptor,
         %{endpoint_id: endpoint_id} = _mapping,
         path
       ) do
    fetch_clause(device_id, interface_id, endpoint_id, path)
  end

  defp fetch_clause(device_id, interface_id, endpoint_id, path) do
    [device_id: device_id, interface_id: interface_id, endpoint_id: endpoint_id, path: path]
  end

  defp normalize_fetch_result({:error, :not_found}, _realm) do
    {:error, :property_not_set}
  end

  # plaintext property value
  defp normalize_fetch_result({:ok, %{value: value}}, _realm) do
    case value do
      nil ->
        {:error, :property_not_set}

      value ->
        {:ok, value}
    end
  end

  # encrypted property value
  defp normalize_fetch_result(
         {:ok, %{encrypted_value: encrypted_value, encrypted_dek: encrypted_dek}},
         realm
       ) do
    case encrypted_value do
      nil ->
        {:error, :property_not_set}

      val ->
        {:ok, decrypt_property_value(val, encrypted_dek, realm)}
    end
  end

  defp decrypt_property_value(nil, _dek, _realm) do
    nil
  end

  # should never happen but let's be defensive
  defp decrypt_property_value(value, nil, _realm) do
    Logger.warning(
      "Attempting to decrypt stored data failed due to missing decryption key",
      tag: "stored_data_decryption_error"
    )

    nil
  end

  defp decrypt_property_value(value, ciphertext_dek, realm) do
    # need to decrypt
    with {:ok, dek} <- Secrets.decrypt_with_kek(realm, ciphertext_dek),
         {:ok, decrypted_value} <- Secrets.decrypt_with_dek(value, dek) do
      :erlang.binary_to_term(decrypted_value)
    else
      _ ->
        Logger.warning(
          "Issue encountered while attempting to decrypt stored data value",
          tag: "stored_data_decryption_error"
        )

        nil
    end
  end
end
