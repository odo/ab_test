# AbTest
A/B testing library written in Elixir.

## Concept

[A/B Tests](https://en.wikipedia.org/wiki/A%2FB_testing) are used to do experiments in product development.
Users (or other entities) are divided into groups that are treated differently and maybe also behave differently as a result.
After collecting data for a while, the data can be broken down by groupe and the difference analyzed. 

This library makes a few assumptions:
- For each test there are two groups: the default and the variant
- Test groups are calculated based on a UUID (or any random string)
- Tests have a start date. If you use the creation date of the user to determine the variant, users never change their test value.
- Tests have a ratio that determines how often the variant is assigned 
- Tests can have a minimum version (usually the first version that handles the variant)
- Tests can have multiple definitions with different start dates and ratios

## Basic Usage

We start with a test configuration JSON:

```
%{
  "pink_ui" => %{
    "definitions" => [
      %{"ratio" => 0.25, "start_at" => "2025-03-01 00:00:00"}
    ],
    "minimum_version" => "1.2.0"
  }
}
```

This configuration defines one test (`pink_ui`) where 25% of users that installed after March 1st 2025 and have at least version 1.2.0" get the variant.
To determine this for a given user, we call:
```
ABTest.Config.from_json_map(config)
|> ABTest.variants_from_config("cf3f53b7-3468-4f27-88b9-20dc3d1ba824", ~N[2025-03-02 00:00:00])
["pink_ui"]
```

If we have a version, we can also pass it here:

```
ABTest.Config.from_json_map(config)
|> ABTest.variants_from_config("cf3f53b7-3468-4f27-88b9-20dc3d1ba824", ~N[2025-03-02 00:00:00], "1.1.0")
[]
```

Note that `ABTest.variants_from_config/3` returns only the variants that apply for the given user.
In the second example, nothing is returned since the version is not new enough.

## Test Evolution

## Conclude with successful default
If the variant was not successful you have two options:

1. You can delete the whole test and all users will get the default immediately. This will also remove the variant for the users that had it before.

2. You add another definition to the test that sets the ratio to `0.0`. This keeps the users that had the variant assigned untouched.

```
%{
  "pink_ui" => %{
    "definitions" => [
      %{"ratio" => 0.25, "start_at" => "2025-03-01 00:00:00"},
      %{"ratio" => 0.00, "start_at" => "2025-03-07 00:00:00"},
    ],
    "minimum_version" => "1.2.0"
  }
}
```

## Conclude with successful variant
If the variant was successful you have two options:

1. You can change the ratio to `1.0` in the existing definition. This will switch on the vaiant for all user, even the ones that where in the default group before. 

2. You can add another definition that switches the variant on for all users, leaving the users who had the default unchanged.

```
%{
  "pink_ui" => %{
    "definitions" => [
      %{"ratio" => 0.25, "start_at" => "2025-03-01 00:00:00"},
      %{"ratio" => 1.00, "start_at" => "2025-03-07 00:00:00"},
    ],
    "minimum_version" => "1.2.0"
  }
}
```


## SQL Version

The underlying functionality can also be implemented in SQL (here PostgreSQL).
This way, analysis can be performed directly in the database:
First, we need a function that calculates an MD5 hash as an integer. 
```sql
CREATE OR REPLACE FUNCTION hash_value(value text)
RETURNS numeric AS $$
  WITH bytes AS (
    SELECT decode(md5(value), 'hex') AS hash_bytes
  )
  SELECT
    SUM(get_byte(hash_bytes, i)::numeric * (256::numeric ^ (15 - i)))
  FROM bytes, generate_series(0, 15) AS i
$$ LANGUAGE SQL IMMUTABLE;
```

Now, we can add a function to compute the actual variant:
```sql
CREATE OR REPLACE FUNCTION variant(entity_hash numeric, test_hash numeric, ratio numeric)
RETURNS boolean AS $$
DECLARE
  max_hash numeric := 340282366920938463463374607431768211456; -- 2^128
  in_min numeric;
  in_max numeric;
BEGIN
  in_min := test_hash;
  in_max := test_hash + (max_hash * ratio);

  IF in_max <= (max_hash - 1) THEN
    -- stretch fits
    RETURN entity_hash > in_min AND entity_hash < in_max;
  ELSE
    -- stretch wraps
    RETURN entity_hash > in_min OR entity_hash < (in_max - (max_hash - 1));
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
```

And a wrapper with the appropriate argument names:
```sql
CREATE OR REPLACE FUNCTION variant(uuid uuid, test_name text, ratio numeric)
RETURNS boolean AS $$
	SELECT variant(hash_value(uuid::TEXT), hash_value(test_name), ratio)
$$ LANGUAGE SQL IMMUTABLE;
```

Now you can determine if a variant applies to a user:
```
SELECT uuid, variant(users.uuid, 'pink_ui', 0.25)
FROM users
LIMIT 4;

dbe34282-e56e-490f-a89b-7a682eacb5c0	FALSE
957b9f0b-2389-4b36-8d55-fb8190fc2cae	FALSE
a59f44f6-2153-408f-b9e5-9ad10625d546	FALSE
be15bbe6-239b-4bbe-8772-2fd173f3d6b6	TRUE
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ab_test` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ab_test, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/ab_test>.

