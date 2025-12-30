defmodule ABTest do

  use TypedStruct

  @max_hash 2**128

  typedstruct do
    field :name, String.t()
    field :ratio, float()
  end

  defmodule Config do
    use TypedStruct

    typedstruct do
      field :name, String.t()
      field :minimum_version, Version.t(), default: Version.parse!("0.0.0")
      field :definitions, [Definition]
    end

    defmodule Definition do
      use TypedStruct

      typedstruct do
        field :start_at, NaiveDateTime.t()
        field :ratio, float()
      end
    end

    @spec from_json_map(map()) :: [%__MODULE__{}]
    def from_json_map(json_map) when is_map(json_map) do
      json_map
      |> Enum.map(
        fn({name, %{"definitions" => values, "minimum_version" => minimum_version_string}}) ->
          definitions =
            values
            |> Enum.map(fn(%{"start_at" => start_at_str, "ratio" => ratio}) ->
              %Definition{start_at: NaiveDateTime.from_iso8601!(start_at_str), ratio: ratio}
            end)
            # we are sorting descending by start time
            |> Enum.sort(fn(a, b) -> NaiveDateTime.after?(a.start_at, b.start_at) end)
          %Config{name: name, definitions: definitions, minimum_version: Version.parse!(minimum_version_string)}
        end)
    end
  end

  def variants_from_config(configs, uuid, inserted_at, version \\ nil) do
    create_tests_from_config(configs, inserted_at, version)
    |> Enum.reduce([],
      fn %__MODULE__{name: name} = test, acc ->
        case variant(uuid, test) do
          true  -> [name | acc]
          false -> acc
        end
      end
    )
  end

  def create_tests_from_config(configs, %DateTime{} = reference_time, version) when is_list(configs) do
    create_tests_from_config(configs, DateTime.to_naive(reference_time), version)
  end
  def create_tests_from_config(configs, reference_time, version) when is_binary(version) do
    create_tests_from_config(configs, reference_time, Version.parse!(version))
  end
  def create_tests_from_config(configs, %NaiveDateTime{} = reference_time, version) when is_list(configs) do
    configs
    |> Enum.map(
      fn(%Config{name: name, definitions: definitions, minimum_version: minimum_version}) ->
        # we are looking for the largest value in the past
        # so the first one to be smaller than the reference
        matching_definition = Enum.find(
          definitions,
          fn(%Config.Definition{start_at: start_at}) ->
            NaiveDateTime.after?(reference_time, start_at) &&
           ((version == nil) || (Version.compare(version, minimum_version) != :lt)) 
          end
        )
        case matching_definition do
          nil ->
            nil
          %{ratio: ratio} ->
            create(name, ratio)
        end
      end
    )
    |> Enum.filter(fn(test) -> test != nil end)
  end

  def create(name, ratio) when is_binary(name) and is_float(ratio) and ratio >= 0 and ratio <= 1.0 do
    %__MODULE__{name: name, ratio: ratio}
  end

  def variant(uuid, %__MODULE__{name: ab_test_name, ratio: ratio}) do
    test_hash = hash_value(ab_test_name)
    entity_hash = hash_value(uuid)
    variant(entity_hash, test_hash, ratio)
  end

  # stretch fits  |........................***************..|
  # stretch wraps |***.....................*****************|
  #                                        ^ test_hash
  #                           ^ user_hash1 = false
  #                                             ^ user_hash2 = true
  # . = false (1-ratio)
  # * = true  (ratio)
  def variant(entity_hash, test_hash, ratio) do
    in_min = test_hash
    in_max = test_hash + (@max_hash * ratio)
    case in_max <= (@max_hash-1) do
      true ->
        # stretch fits
        entity_hash > in_min and entity_hash < in_max
      false ->
        # stretch wraps
        entity_hash > in_min or entity_hash < (in_max - (@max_hash-1))
    end
  end

  defp hash_value(value) when is_binary(value) do
    <<hash::128>> = :crypto.hash(:md5, value)
    hash
  end
end

