# TestSHACL

Working with SHACL and Elixir - Applying SPARQL.ex to RDF shapes.

**TODO: Add description**

Following up on my last a project about querying RDF using the Elixir
`SPARQL.ex` and `SPARQL.Client.ex` libraries from Marcel Otto, I wanted
to focus here on a simple use case with SHACL and an RDF shape used to
provide a template description for the result graph. That is, instead of
using a specific SPARQL query we will generate SPARQL queries from the
RDF shape that defines the valid result graphs. And in doing so we will
also bump up against some limitations with the current `SPARQL.ex`
implementation and show how we might work around those.

## Review querying scenarios

## Create a `TestSHACL` project

As usual, let's create a new project `TestSHACL` with `mix` (and note
this time we use the `module` option to pass the desired project name
`TestSHACL` instead of the default casing `TestShacl`):

```bash
bash> mkdir test_shacl; cd test_shacl
bash> mix new . --module TestSHACL
```

We'll add the packages a static code analysis tools and test of the
notifier.

```elixir
# config/config.exs
use Mix.Config

if Mix.env == :dev do
  config :tesla, :adapter, Tesla.Adapter.Hackney
  config :mix_test_watch, clear: true
  config :remix, escript: true, silent: true
end

if Mix.env == :test do
  config :ex_unit_notifier,
    notifier: ExUnitNotifier.Notifiers.NotifySend
end

# import_config "#{Mix.env()}.exs"
```

```elixir
# test/test_helper.exs
ExUnit.configure formatters: [ExUnit.CLIFormatter, ExUnitNotifier]
ExUnit.start()
```

```elixir
# mix.exs
defmodule TestSHACL.MixProject do
  use Mix.Project

  def project do
    [
      app: :test_shacl,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: applications(Mix.env)
    ]
  end

  defp deps do
    [
      {:credo, "~> 0.10.0", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.10.1", only: :test},
      {:ex_unit_notifier, "~> 0.1.4", only: :test},
      {:hackney, "~> 1.14.3"},
      {:mix_test_watch, "~> 0.9.0", only: :dev, runtime: false},
      {:sparql_client, "~> 0.2.1"},
      {:remix, "~> 0.0.2", only: :dev}
    ]
  end

  defp applications(:dev), do: applications(:all) ++ [:remix]
  defp applications(_all), do: [:logger]
end
```

Run it code: `bash> make packs; make all`

We'll then declare a dependency on `SPARQL.Client.ex` in the `mix.exs`
file. And we'll also use the `hackney` HTTP client in Erlang as
recommended. And we added this line to the `config.exs` file:
`config :tesla, :adapter, Tesla.Adapter.Hackney`. We then use Mix to add
in the dependency: `make packs`.

### 8 November 2018 by Oleg G.Kapranov
