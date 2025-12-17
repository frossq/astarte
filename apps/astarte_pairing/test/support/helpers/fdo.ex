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

defmodule Astarte.Helpers.FDO do
  import StreamData

  alias Astarte.Core.Interface.Ownership
  alias Astarte.Pairing.FDO.OwnershipVoucher.Core
  alias Astarte.DataAccess.FDO.OwnershipVoucher, as: DBOwnershipVoucher
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.Pairing.FDO.OwnershipVoucher
  alias Astarte.Pairing.FDO.OwnershipVoucher.CreateRequest
  alias Astarte.Pairing.FDO.OwnershipVoucher.RendezvousInfo
  alias Astarte.Pairing.FDO.OwnershipVoucher.RendezvousInfo.RendezvousDirective
  alias Astarte.Pairing.FDO.OwnershipVoucher.RendezvousInfo.RendezvousInstr

  @sample_voucher_ec256 """
  -----BEGIN OWNERSHIP VOUCHER-----
  hRhlWM+GGGVQr63QkMp3nYL1GhV8NSIHDIGEggNDGR+SggJFRH8AAAGCBEMZH5KC
  DEEBa3Rlc3QtZGV2aWNlgwoBWFswWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAAR+
  ZAJTHLueZHU5DX1qdH6ZvbvmW69aO2RK+uJ20YSmeJZTp1TiV3jpdBhyEOr1pY1O
  jPvl3vS/j/gbrSCwr+rfgjgqWDBZh6iPbdAa5zursMvPQeFRIFck3btlLPsXozLj
  E0eV+ktxM0RdDTSr93qKaHcxyVOCBlgwwbWxktdFSJYycNKe/nOUEM/38hWmgZqT
  KTuhUp5bj+njyqipW+XieEZWi/hI4aLQglkBPjCCATowgeGgAwIBAgIJANsx49Cs
  aXDMMAoGCCqGSM49BAMDMDAxDzANBgNVBAMMBkRldmljZTEQMA4GA1UECgwHRXhh
  bXBsZTELMAkGA1UEBhMCVVMwHhcNMjUxMDI3MTQyMTQxWhcNMzUxMDI1MTQyMTQx
  WjAWMRQwEgYDVQQDDAt0ZXN0LWRldmljZTBZMBMGByqGSM49AgEGCCqGSM49AwEH
  A0IABP2JVosdcxoaEhwUM0Cs3o7RpyTVVWA3m7/fa4NpjSD2l4LFAAnDmQeQmGEA
  Zb7bDegDV25BJGJZEllUykjpDCswCgYIKoZIzj0EAwMDSAAwRQIgCzLXLWA+HyzK
  SbOjsey72cVUyIseO5ZccBqk3riDaMwCIQCn6GGwvDYrqFCv7E/S4CavqIjh2qTn
  Zrw5SPrFFlaQNFkBVzCCAVMwgfqgAwIBAgIIONKn09qIvrMwCgYIKoZIzj0EAwIw
  MDEPMA0GA1UEAwwGRGV2aWNlMRAwDgYDVQQKDAdFeGFtcGxlMQswCQYDVQQGEwJV
  UzAeFw0yNTEwMjcxMjAwMTJaFw0yNjEwMjcxMjAwMTJaMDAxDzANBgNVBAMMBkRl
  dmljZTEQMA4GA1UECgwHRXhhbXBsZTELMAkGA1UEBhMCVVMwWTATBgcqhkjOPQIB
  BggqhkjOPQMBBwNCAAS2VYoG7RvZJ3viS2iIJHJ3Kc6RBxrLvU4cXMwzf3BVmbMD
  0Fm7RCul90MY0HA70mo2uliQl+hBIPt6CZL88HnlMAoGCCqGSM49BAMCA0gAMEUC
  IQD8o8cHYlu173xtkO+iYWDz1YtlHX5qgM+5eI+bAxiWDQIgeAI42brmHjg8k8uL
  hCBiOubCszNsE8nt95lmrbx4SPeB0oRDoQEmoFjMhII4KlgwjcflehRF07wE+oSS
  rvbtBDn2SfN2NJY5BoIR3cJwaW2BHUILDIp6dK+MFEU8gMgngjgqWDAlmi74Lcun
  Drl3FFJMbuEkFbijwOnEwLkK5YRtjZHZhqCjiNAj7dJZdbOTzaauvnD2gwoBWFsw
  WTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAARL5OQDtW0lC/1hDvnKXlu1cpH9yyjJ
  8vNhZRODFWIYx8mS+qXhbfOu1FpU9T0jTpM4cULYzDL71LcDtRa/8Ra2WEDgl/oT
  yVhaI7XTPziNidQB/6h7rAsYKGjb1odrsLdmeFObSIdVHgG3GLGc/mq/3AMhy5tl
  rPbEwDSoPhfFnX0W
  -----END OWNERSHIP VOUCHER-----
  """

  @sample_private_key_ec256 """
  -----BEGIN EC PRIVATE KEY-----
  MHcCAQEEIFlbTEE1Ce+RSqhU8FqxsY7eNb9BaBWOTw6qFv7l0DZtoAoGCCqGSM49
  AwEHoUQDQgAEocPEIHIrn08VRO5zkkDztwp72Sw0BSm0mZeLgOKkHLUPdVFFlc0E
  O82b1/S2Cwzwh8MIDDx0CN2b+IBl5bRwOw==
  -----END EC PRIVATE KEY-----
  """

  @sample_private_key_ec384 """
  -----BEGIN EC PRIVATE KEY-----
  MHYCAQEEIEIqG/z7xY2e/dYxR21rS+P7W79i/XjD3t027f31j+sboAcGBQQAAADd
  oAIBMAgGCCqGSM49AwEHoUQDQgAEy36pB90gXpX19Fp6D99b5M60h6+3b8X7Lp3E
  m6q4m/s+e8uQ6o8054zO9y1iXW9oR5bB96l2D4Xf02L18oUfGwL9Q==
  -----END EC PRIVATE KEY-----
  """

  @sample_rsa_private_key """
  -----BEGIN PRIVATE KEY-----
  MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCphTib16sbghc+
  tVaqAl5WcebrBe4vxGH0cDFcVmXlIQjfh020ePYvqG+6PVitIRQ8sGgx5t+yT06l
  CG2z0YVq8mpVXFLC7YLCjBVlms6QFcBshkxVRU2jj8vuhP/SIf0Ze9kbeN4HKDji
  csoAXy8bUXVTQRgd7yCCULL35LdXHIQ2iwDxuBpVgjczk4swSqa2YMy8BIFLbmSZ
  ENAsS2KeP0f4OO9HFzOF1eT0yUTdOmNrBKzvsk+AeKNt0MXf8zbAulIrRZIgUyZe
  Creq75XbXapRrZitfbZyX6ZvWQykQLDCyOFAv4fWMd/8JHuqAZsqGACDEm0cU8eA
  Z4Z+L4lRAgMBAAECggEADOh+XqzgdEVxUa7AkkzV3s0+Nn01cuEITchRPzpmTePj
  EhTydMs/1nHZTXF9vskltQKrHHRRFPnMVO1nCmnqN9ziU0JRcahg7EF7IPPVxiDx
  4xGi3wdaRG8e/zg/ZpfR9vki7LWaan8Z6HGx3K9iyI4Tr1WQlDmbhxtv//JO3Pdz
  hqEdrGIEU2lJ7t+IGOLamSL1Q+fPSbENBdnFBdu4SiSJpBJno7YRZVp7weW41jYx
  svPBnLAibUDyGXEbHqSEs/vy3IEYxjH+Ioyambqh8YR19FzBy6ld1kipt6ddE+Zu
  O/ApnzrAfAxbpEMfqLcoYuF1GawjOF72zck2QM0GBQKBgQDRa2WB/mQkQlVIpMuH
  QAgqLuaYv6dlzEkl4NOrv3kyNYLWDWqdJzF13a1ICuvgQX71jNMI/NDI1uxrEbK2
  /5sC00cHACPs2zlMmNvvstv4TQVVl9ioaEn4Y2ONsv+nSD/p0fv9lJZABoCy4yXS
  BCQudWaTvqFNTCJuvPxEcmIi1wKBgQDPOet2BBWhbSgtdZYwNJNcQzQtGgLCd4TL
  uqS4yMeLpKmT9zfOhOdGOlVSssMStDwGEKqBrNp9/Wt9giL8/F9ZkoyKbmvGlRI9
  z17XPTdJAd3+DnS+l1ulCt9M9Ysrf1s17uHGCSFgxSHuOW2KlgF7lKOb+RjK53S+
  sMeLD6/YFwKBgA4/m2Fz2IZrCPhvVfW20pdkJ4ZfC9muQ4/TMzOtTGaxI1zC/u0A
  XKojUgXj0FaqviOg2D71TJNNpDpIsvsmevp/O4braIZWCBkBEX3GkpbbTrCbKz+S
  EO5YfM6ITkKodMjI47dGI87pYlpJgCpA4+FRVZBZ2Qm0U2drblKN4cVzAoGBAMDA
  /2QnKHefMWAXoDv2q5uGZ2IMb8Szp7JZSh8Xo4UhBRu9OQvAU9/fIr5pyUn8nFiH
  6BH21sWalAGKq0Dm/0oyJsgdLeLphq431eAf8OzX78YBbFZcM8Kw+kR7oZg0PoNM
  UHYEyCdbNtSAVoQyQ+7Ps9/BNG6IHO/DP9j6HnbBAoGAcErnhRKOWZeX2X5gFkjw
  CQ1QSdjNLsJEOXcm1SPCFrDF9bLtuyIynkPeUFB2ki82gBaH4qx/5eEG//6KfFwG
  9nMKvSEg2D0Iy6l9xhqfrE0e8fPdsLSZVPANCr90QNEahvWxpoeR+uZouWI49VxK
  qbAKYV8ryPBy2s+b+5IstCI=
  -----END PRIVATE KEY-----
  """

  @sample_device_guid <<175, 173, 208, 144, 202, 119, 157, 130, 245, 26, 21, 124, 53, 34, 7, 12>>

  @sample_request_rc_ec256 CreateRequest.changeset(%CreateRequest{}, %{
                             ownership_voucher: @sample_voucher_ec256,
                             private_key: @sample_private_key_ec256
                           })
                           |> Ecto.Changeset.apply_action!(:insert)

  @sample_request_rsa CreateRequest.changeset(%CreateRequest{}, %{
                        ownership_voucher: @sample_voucher_ec256,
                        private_key: @sample_rsa_private_key
                      })
                      |> Ecto.Changeset.apply_action!(:insert)

  @sample_rv_info %RendezvousInfo{
    directives: [
      %RendezvousDirective{
        instructions: [
          %RendezvousInstr{
            rv_value: "ufdo.astarte.localhost",
            rv_variable: :dns
          },
          %RendezvousInstr{
            rv_value: <<1>>,
            rv_variable: :protocol
          },
          %RendezvousInstr{
            rv_value: <<24, 80>>,
            rv_variable: :dev_port
          },
          %RendezvousInstr{
            rv_value: <<25, 31, 105>>,
            rv_variable: :owner_port
          },
          %RendezvousInstr{
            rv_value: "\n",
            rv_variable: :delaysec
          }
        ]
      }
    ]
  }

  def sample_voucher_ec256, do: @sample_voucher_ec256
  def sample_cbor_voucher_ec256, do: @sample_request_rc_ec256.cbor_ownership_voucher
  def sample_private_key_ec256, do: @sample_private_key_ec256
  def sample_extracted_private_key_ec256, do: @sample_request_rc_ec256.extracted_private_key
  def sample_extracted_rsa_private_key, do: @sample_request_rsa.extracted_private_key
  def sample_rsa_private_key, do: @sample_rsa_private_key
  def sample_device_guid, do: @sample_device_guid
  def sample_rv_info, do: @sample_rv_info

  def sample_ownership_voucher_ec256 do
    {:ok, voucher} = OwnershipVoucher.decode_cbor(sample_cbor_voucher_ec256())
    voucher
  end

  def nonce, do: binary(length: 16)

  def hello_ack(nonce) do
    CBOR.encode([%CBOR.Tag{tag: :bytes, value: nonce}])
  end

  def insert_voucher(realm_name, private_key, cbor_voucher, device_id) do
    %DBOwnershipVoucher{
      voucher_data: cbor_voucher,
      private_key: private_key,
      device_id: device_id
    }
    |> Repo.insert(prefix: Realm.keyspace_name(realm_name))
  end

  def v_384() do
    p_k_384 =
      <<48, 115, 48, 19, 6, 7, 42, 134, 72, 206, 61, 2, 1, 6, 8, 43, 129, 4, 0, 34, 3, 92, 0, 4,
        1, 148, 241, 204, 185, 102, 194, 219, 117, 104, 180, 20, 207, 186, 222, 172, 195, 230,
        240, 169, 137, 163, 100, 224, 70, 77, 167, 115, 207, 135, 224, 46, 78, 252, 92, 196, 235,
        125, 245, 146, 225, 237, 244, 219, 18, 107, 166, 216, 215, 135, 12, 120, 194, 13, 106,
        172, 153, 153, 220, 135, 171, 152, 210, 89, 214, 192, 116, 250, 224, 94, 173, 146, 178,
        247, 19, 178, 182, 114, 234, 106, 32, 211, 232, 23, 120, 10, 140, 214, 39, 133, 213, 200,
        215, 162, 121, 20, 231, 231, 180, 188, 77, 128, 211, 228, 75, 164, 133, 133, 134, 95, 212,
        190, 226, 160, 207, 151, 101, 16, 207, 253, 133, 181, 106, 195, 135, 173, 85, 227, 200,
        165, 161, 253, 76, 229, 233, 18, 184, 141, 179, 174, 160, 169, 217, 34, 254, 15, 254, 184,
        160, 8, 144, 175, 222, 111, 153, 150, 171, 74, 95, 9, 246, 138, 199, 135, 109, 109, 223,
        239, 132, 196, 223, 206, 152, 242, 117, 85, 155, 123, 17, 34, 146, 33, 175, 141, 195, 237,
        212, 148, 166, 131, 88, 154, 234, 171, 168, 75, 204, 109, 224, 140, 199, 18, 16, 212, 126,
        218, 93, 201, 38, 222, 103, 144, 104, 216, 125, 245, 115, 237, 176, 144, 199, 42, 215,
        140, 184, 76, 191, 139, 13, 100, 48, 70, 24, 177, 22, 218, 200, 163, 248, 106, 205, 109,
        193, 247, 88, 120, 118, 205, 109, 115, 120, 249, 186, 200, 204, 91, 114, 237, 234, 73,
        245, 120, 200, 105, 160, 4, 104, 200, 211, 213, 211, 251, 221, 213, 141, 215, 164, 170,
        71, 104, 13, 75, 237, 139, 168, 169, 19, 10, 142, 133, 243, 201, 105, 179, 11, 151, 156,
        177, 218, 190, 8, 23, 25, 196, 47, 186, 157, 32, 221, 202, 17, 140, 125, 19, 199, 255,
        142, 17, 112, 113, 125, 33, 179, 241, 140, 200, 45, 199, 93, 160, 210, 221, 128, 18, 248,
        114, 201, 249, 215, 175, 171, 74, 9, 139, 239, 113, 207, 196, 102, 121, 12, 79, 165, 237,
        119, 166, 138, 227, 213, 140, 129, 202, 185, 236, 197, 209, 202, 158, 225, 254, 210, 166,
        139, 131, 206, 214, 190, 93, 145, 24, 228, 172, 108, 15, 132, 243, 154, 205, 112, 146,
        201, 230, 200, 248, 130, 83, 16, 163, 104, 168, 180, 229, 231, 242, 10, 216, 219, 106,
        180, 121, 207, 191, 113, 85, 96, 76, 229, 17, 72, 239, 119, 18, 102, 85, 153, 250, 122,
        165, 249, 216, 14, 76, 229, 123, 81, 183, 157, 198, 238, 11, 151, 165, 145, 123, 243, 86,
        238, 108, 204, 150, 229, 14, 180, 250, 126, 150, 109, 229, 13, 190, 196, 217, 98, 93, 242,
        241, 23, 13, 237, 130, 199, 102, 164, 131, 238, 189, 79, 224, 75, 152, 169, 194, 221, 232,
        239, 124, 185, 30, 11, 132, 162, 16, 210, 129, 160, 143, 227, 207, 248, 246, 181, 208,
        195, 255, 34, 237, 141, 91, 113, 112, 200, 115, 22, 157, 14, 155, 109, 188, 180, 167, 73,
        237, 164, 156, 207, 149, 100, 242, 226, 123, 76, 172, 103, 74, 244, 239, 159, 124, 106,
        208, 201, 162, 143, 91, 248, 196, 125, 182, 113, 151, 108, 122, 156, 127, 19, 144, 168,
        77, 168, 232, 232, 242, 249, 203, 189, 243, 225, 213, 10, 103, 186, 104, 255, 172, 147,
        34, 38, 160, 244, 219, 232, 132, 247, 9, 251, 89, 188, 70, 171, 72, 255, 22, 42, 196, 222,
        85, 148, 123, 175, 122, 18, 90, 119, 12, 139, 237, 102, 33, 169, 20, 221, 185, 115, 21,
        120, 10, 181, 16, 135, 192, 118, 155, 159, 8, 113, 93, 203, 40, 48, 140, 181, 115, 42,
        143, 166, 25, 197, 183, 133, 146, 16, 246, 172, 90, 185, 133, 108, 23, 254, 212, 220, 139,
        235, 114, 243, 226, 109, 176, 88, 235, 230, 223, 174, 9, 73, 239, 156, 163, 19, 233, 18,
        157, 13, 18, 236, 16, 73, 238, 242, 170, 112, 100, 250, 11, 47, 86, 145, 121, 131, 221,
        231, 104, 24, 76, 209, 10, 220, 95, 23, 81, 115, 236, 115, 189>>

    {:ok, v} = sample_cbor_voucher_ec256() |> OwnershipVoucher.decode_cbor()
    v.header.public_key

    new_pk = %Astarte.Pairing.FDO.Types.PublicKey{
      body: p_k_384,
      encoding: :x509,
      type: :secp384r1
    }

    v2 = update_in(v, [:header, :publc_key], fn _ -> new_pk end)
    v2.header.public_key
  end
end
