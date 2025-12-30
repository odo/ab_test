defmodule PetAi.ABTestTest do
  use ExUnit.Case

  @max_hash 2**128

  setup do
    uuid = "cf3f53b7-3468-4f27-88b9-20dc3d1ba822"
    inserted_at = DateTime.utc_now()
    %{uuid: uuid, inserted_at: inserted_at}
  end

  test "variant gets computed", %{uuid: uuid} do
    ab_test = ABTest.create("the test", 0.5)
    variant = ABTest.variant(uuid, ab_test)
    assert false == variant
  end

  test "variant with fitting stretch" do
    # stretch goes from 10% to 35%
    test_hash = @max_hash * 0.10
    ratio = 0.25
    assert false == ABTest.variant(0.05 * @max_hash, test_hash, ratio)
    assert false == ABTest.variant(0.09 * @max_hash, test_hash, ratio)
    assert true  == ABTest.variant(0.11 * @max_hash, test_hash, ratio)
    assert true  == ABTest.variant(0.34 * @max_hash, test_hash, ratio)
    assert false == ABTest.variant(0.36 * @max_hash, test_hash, ratio)
  end

  test "variant with wrapping stretch" do
    # stretch goes from 80% to 25%
    test_hash = @max_hash * 0.80
    ratio = 0.45
    assert true ==  ABTest.variant(0.00 * @max_hash, test_hash, ratio)
    assert true ==  ABTest.variant(0.24 * @max_hash, test_hash, ratio)
    assert false == ABTest.variant(0.26 * @max_hash, test_hash, ratio)
    assert false == ABTest.variant(0.79 * @max_hash, test_hash, ratio)
    assert true  == ABTest.variant(0.81 * @max_hash, test_hash, ratio)
    assert true  == ABTest.variant(1.00 * @max_hash, test_hash, ratio)
  end

  test "create tests from config" do
    config =
    %{
      "pink_ui" => %{
        "definitions" => [
          %{"ratio" => 0.5, "start_at" => "2025-03-28 00:00:00"},
          %{"ratio" => 0.0, "start_at" => "2025-04-28 00:00:00"}
        ],
        "minimum_version" => "1.0.0"
      }
    }
    |> ABTest.Config.from_json_map()
    sufficient_version   = "1.0.0"
    insufficient_version = "0.1.0"
    assert [] == ABTest.create_tests_from_config(config, ~N[2025-01-01 00:00:00], sufficient_version)
    assert [%ABTest{name: "pink_ui", ratio: 0.5}] == ABTest.create_tests_from_config(config, ~N[2025-03-29 00:00:00], sufficient_version)
    assert [%ABTest{name: "pink_ui", ratio: 0.0}] == ABTest.create_tests_from_config(config, ~N[2025-04-29 00:00:00], sufficient_version)
    assert [] == ABTest.create_tests_from_config(config, ~N[2025-04-29 00:00:00], insufficient_version)
  end

  test "user variants from config", %{uuid: uuid} do
    config =
    %{
      "pink_ui" => %{
        "definitions" => [
          %{"ratio" => 0.5, "start_at" => "2025-03-28 00:00:00"},
          %{"ratio" => 0.0, "start_at" => "2050-04-28 00:00:00"}
        ],
        "minimum_version" => "6.6.6"
      },
      "rats_as_pets" => %{
        "definitions" => [%{"ratio" => 1.0, "start_at" => "2020-01-01 00:00:00"}],
        "minimum_version" => "7.7.7"
      }
    }
    |> ABTest.Config.from_json_map()
    early_inserted_at = ~N[2023-03-29 00:00:00]
    assert ["rats_as_pets"] == ABTest.variants_from_config(config, uuid, early_inserted_at)
    late_user_inserted_at = ~N[2025-03-29 00:00:00]
    assert ["rats_as_pets", "pink_ui"] == ABTest.variants_from_config(config, uuid, late_user_inserted_at)
  end

end
