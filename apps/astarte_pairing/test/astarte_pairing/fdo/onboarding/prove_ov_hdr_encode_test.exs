defmodule Astarte.Pairing.FDO.OwnerOnboarding.ProveOVHdrEncodeTest do
  use ExUnit.Case, async: true

  alias Astarte.Pairing.FDO.OwnerOnboarding.ProveOVHdr
  alias Astarte.Pairing.FDO.OwnershipVoucher.Header, as: OVHeader
  alias Astarte.Pairing.FDO.Types.Hash

  describe "encode/1" do
    test "correctly encodes a valid ProveOvHdr payload into CBOR list" do
      shared_random_binary = :crypto.strong_rand_bytes(32)

      rv_variable_1 = [
        1,
        shared_random_binary |> binary_part(0, 16) |> CBOR.encode() |> COSE.tag_as_byte()
      ]

      rv_variable_2 = [
        2,
        shared_random_binary |> binary_part(0, 16) |> CBOR.encode() |> COSE.tag_as_byte()
      ]

      cbor_ov_header =
        [
          # OVHProtVer
          1,
          # OVGuid
          shared_random_binary |> binary_part(0, 16), # |> COSE.tag_as_byte(),
          # OVRVInfo
          [[rv_variable_1, rv_variable_2]],
          # OVDeviceInfo
          "no",
          # OVPubKey
          # FIXME
          :crypto.strong_rand_bytes(64),
          # OVDevCertChainHash
          [:sha256, shared_random_binary]
        ]
        |> CBOR.encode()
        #|> COSE.tag_as_byte()

      num_ov_entries = 10
      cbor_hmac = [:sha256, shared_random_binary] |> CBOR.encode()
      nonce_to2_prove_ov = shared_random_binary
      eb_sig_info = :es256
      xa_key_exchange = shared_random_binary
      hello_device_hash = %Hash{type: :sha256, hash: shared_random_binary}
      max_owner_message_size = 1500

      # cbor_payload =
      #   [
      #     ovhdr,
      #     num_ov_entries,
      #     hmac,
      #     nonce_to2_prove_ov,
      #     eb_sig_info,
      #     xa_key_exchange,
      #     hello_device_hash,
      #     max_owner_message_size
      #   ]
      #   |> CBOR.encode()

      prove_ov_hdr_payload = %ProveOVHdr{
        cbor_ov_header: cbor_ov_header,
        num_ov_entries: num_ov_entries,
        cbor_hmac: cbor_hmac,
        nonce_to2_prove_ov: nonce_to2_prove_ov,
        eb_sig_info: eb_sig_info,
        xa_key_exchange: xa_key_exchange,
        hello_device_hash: hello_device_hash,
        max_owner_message_size: max_owner_message_size
      }

      encoded_prove_hdr_msg = ProveOVHdr.encode_cbor(prove_ov_hdr_payload) |> dbg()
      # TODO put COSE on top

      # ...e poi il decode a mano e verificare il contenuto
      # guarda ci siano i CBOR.Tag (che vengon messi dall'encode)

      decoded_prove_hdr_msg = CBOR.decode(encoded_prove_hdr_msg) |> dbg()


      # assert {:ok, %DeviceServiceInfo{} = msg} = DeviceServiceInfo.decode(cbor_payload)
      # assert msg.is_more_service_info == false
      # assert msg.service_info == []
    end

    #     test "correctly decodes a valid payload with data (IsMore=true)" do
    #       info_list = ["devmod:os", "linux", "devmod:version", "1.0"]
    #       cbor_payload = CBOR.encode([true, info_list])

    #       assert {:ok, msg} = DeviceServiceInfo.decode(cbor_payload)
    #       assert msg.is_more_service_info == true
    #       assert msg.service_info == info_list
    #     end

    #     test "correctly decodes a Astarte ServiceInfo payload " do
    #       complex_service_info = [
    #         "astarte:active",
    #         true,
    #         "astarte:realm",
    #         "test_realm",
    #         "astarte:secret",
    #         "super_secret_credential",
    #         "astarte:baseurl",
    #         "http://api.astarte.localhost",
    #         "astarte:deviceid",
    #         "2TBn-jNESuuHamE2Zo1anA",
    #         "astarte:nummodules",
    #         1,
    #         "astarte:modules",
    #         [1, 0, "astarte_interface_1", "astarte_interface_2"]
    #       ]

    #       cbor_payload = CBOR.encode([true, complex_service_info])

    #       assert {:ok, msg} = DeviceServiceInfo.decode(cbor_payload)

    #       assert msg.is_more_service_info == true
    #       assert is_list(msg.service_info)

    #       assert msg.service_info == complex_service_info

    #       expected_nested_list = List.last(complex_service_info)
    #       assert List.last(msg.service_info) == expected_nested_list
    #     end

    #     test "returns error if IsMoreServiceInfo is not a boolean" do
    #       cbor_payload = CBOR.encode([1, []])

    #       assert {:error, :invalid_is_more_type} = DeviceServiceInfo.decode(cbor_payload)
    #     end

    #     test "returns error if IsMoreServiceInfo is nil" do
    #       cbor_payload = CBOR.encode([nil, []])

    #       assert {:error, :invalid_is_more_type} = DeviceServiceInfo.decode(cbor_payload)
    #     end

    #     test "returns error if ServiceInfo is not a list" do
    #       cbor_payload = CBOR.encode([true, %{}])

    #       assert {:error, :invalid_service_info_type} = DeviceServiceInfo.decode(cbor_payload)
    #     end

    #     test "returns error if ServiceInfo is a simple string" do
    #       cbor_payload = CBOR.encode([true, "devmod:os"])

    #       assert {:error, :invalid_service_info_type} = DeviceServiceInfo.decode(cbor_payload)
    #     end

    #     test "returns error on invalid structure (list too short)" do
    #       # Manca l'elemento service_info
    #       cbor_payload = CBOR.encode([true])

    #       assert {:error, :invalid_structure} = DeviceServiceInfo.decode(cbor_payload)
    #     end

    #     test "returns error on invalid structure (list too long)" do
    #       cbor_payload = CBOR.encode([true, [], "extra_garbage"])

    #       assert {:error, :invalid_structure} = DeviceServiceInfo.decode(cbor_payload)
    #     end

    #     # test "returns error on malformed CBOR" do
    #     #   cbor_payload = <<0xFF, 0x00, 0xFF>>
    #     #
    #     #   assert {:error, :invalid_cbor} = DeviceServiceInfo.decode(cbor_payload)
    #     # end
    #   end

    #   describe "to_cbor_list/1" do
    #     test "converts struct to raw list correctly" do
    #       msg = %DeviceServiceInfo{
    #         is_more_service_info: true,
    #         service_info: ["test_key", "test_val"]
    #       }

    #       assert [true, ["test_key", "test_val"]] == DeviceServiceInfo.to_cbor_list(msg)
    #     end
  end
end
