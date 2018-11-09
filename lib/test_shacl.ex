defmodule TestSHACL do
  @moduledoc """
  Top-level module used in "Working with SHACL and Elixir"
  """

  alias RDF.Turtle
  alias SPARQL.Query.Result

  @priv_dir "#{:code.priv_dir(:test_shacl)}"

  @data_dir @priv_dir <> "/data/"
  @data_file "978-1-68050-252-7.ttl"

  @shapes_dir @priv_dir <> "/shapes/"
  @shape_file "book_shape.ttl"

  @shapes_queries_dir @priv_dir <> "/shapes/queries/"
  @shape_query_file "book_shape_query.rq"

  @shapes_queries_dir @priv_dir <> "/shapes/queries/"
  @shape_query_helper_file "book_shape_query_helper.rq"

  @doc """
  Reads default RDF model in Turtle format.
  """
  def data do
    Turtle.read_file!(@data_dir <> @data_file)
  end

  @doc """
  Reads default RDF shape in Turtle format.
  """
  def shape do
    Turtle.read_file!(@shapes_dir <> @shape_file)
  end

  @doc """
  Reads default SPARQL query for default RDF shape.
  """
  def shape_query do
    File.read!(@shapes_queries_dir <> @shape_query_file)
  end

  @doc """
  Reads simple SPARQL query for default RDF shape.
  """
  def shape_query_helper do
    File.read!(@shapes_queries_dir <> @shape_query_helper_file)
  end

  @doc """
  Makes a SPARQL query by querying default RDF shape - demo only.
  """
  def query_from_shape(shape, shape_query) do
    qh = "select ?s ?p ?o\nwhere {\n"
    qt = "}\n"

    result = SPARQL.execute_query(shape, shape_query)

    # add the subject type
    s = result |> Result.get(:s) |> List.first
    q = qh <> "  ?s a <#{s}> .\n"

    # add the properties
    q = q <> List.to_string(
      result
      |> Result.get(:p)
      |> Enum.map(&("  ?s <#{&1}> ?o .\n  ?s ?p ?o .\n"))
    )
    q <> qt
  end

  @doc """
  Makes a list of SPARQL queries by querying default RDF shape.
  """
  def queries_from_shape(shape, shape_query) do
    qh = "select ?s ?p ?o\nwhere {\n"
    qt = "}\n"

    result = SPARQL.execute_query(shape, shape_query)

    s = result |> Result.get(:s) |> List.first

    (result |> Result.get(:p))
    |> Enum.map(
      &(qh
        <> "  # bind (<#{&1}> as ?p)\n"
        <> "  ?s a <#{s}> .\n"
        <> "  ?s <#{&1}> ?o .\n"
        <> " ?s ?p ?o .\n"
        <> qt
      )
    )
  end
end
