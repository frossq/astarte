#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.SessionTest do
  use Astarte.Cases.Data, async: true

  alias Astarte.Pairing.FDO.OwnerOnboarding.HelloDevice
  alias Astarte.Pairing.FDO.OwnerOnboarding.Session
  alias Astarte.Pairing.FDO.OwnerOnboarding.SessionKey

  import Astarte.Helpers.FDO

  setup_all do
    hello_device_ec256 = HelloDevice.generate(:ec256)
    ownership_voucher_ec256 = sample_ownership_voucher_ec256()
    owner_key_ec256 = sample_extracted_private_key_ec256()
    device_key_ec256 = COSE.Keys.ECC.generate(:es256)
    {:ok, device_random_ec256, xb_ec256} = SessionKey.new(hello_device_ec256.kex_name, device_key_ec256)

    ec256_setup = %{
      hello_device: hello_device_ec256,
      ownership_voucher: ownership_voucher_ec256,
      owner_key: owner_key_ec256,
      device_key: device_key_ec256,
      device_random: device_random_ec256,
      xb: xb_ec256
    }

    # hello_device_ec384 = HelloDevice.generate(:ec384)
    # ownership_voucher_ec384 = sample_ownership_voucher_ec384()
    # owner_key_ec384 = sample_extracted_private_key_ec384()
    # device_key_ec384 = COSE.Keys.ECC.generate(:es384)
    # {:ok, device_random_ec384, xb_ec384} = SessionKey.new(hello_device_ec384.kex_name, device_key_ec384)
  end

  setup context do
    %{
      astarte_instance_id: astarte_instance_id,
      hello_device: hello_device,
      ownership_voucher: ownership_voucher,
      realm: realm_name,
      owner_key: owner_key
    } = context

    {:ok, session} =
      Session.new(realm_name, hello_device, ownership_voucher, owner_key)

    on_exit(fn ->
      setup_database_access(astarte_instance_id)
      delete_session(realm_name, session.key)
    end)

    %{session: session}
  end

  describe "new/5" do
    test "returns required session information", context do
      %{
        realm: realm_name,
        hello_device: hello_device,
        owner_key: owner_key,
        ownership_voucher: ownership_voucher
      } = context

      assert {:ok, session} = Session.new(realm_name, hello_device, ownership_voucher, owner_key) |> dbg()
      assert is_binary(session.key)
      assert session.prove_dv_nonce
      assert session.owner_random
      assert session.xa
      assert {:es256, %COSE.Keys.ECC{}} = session.device_signature
    end
  end

  describe "build_session_secret/4" do
    test "returns the shared secret", context do
      %{
        realm: realm_name,
        xb: xb,
        session: session,
        owner_key: owner_key
      } = context

      assert {:ok, new_session} = Session.build_session_secret(session, realm_name, owner_key, xb)
      assert is_binary(new_session.secret)
    end
  end

  describe "derive_key/2" do
    setup context do
      %{
        realm: realm_name,
        xb: xb,
        session: session,
        owner_key: owner_key
      } = context

      {:ok, session} = Session.build_session_secret(session, realm_name, owner_key, xb)

      %{session: session}
    end

    test "returns the derived key", context do
      %{
        realm: realm_name,
        session: session
      } = context

      assert {:ok, session} = Session.derive_key(session, realm_name)
      assert %COSE.Keys.Symmetric{k: binary_key, alg: alg} = session.sevk
      assert is_binary(binary_key)
      assert alg == :aes_256_gcm
    end
  end
end
