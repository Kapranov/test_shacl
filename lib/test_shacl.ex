defmodule TestSHACL do
  @moduledoc """
  Top-level module used in "Working with SHACL and Elixir"
  """

  alias RDF.Turtle

  @priv_dir "#{:code.priv_dir(:test_shacl)}"

  @data_dir @priv_dir <> "/data/"
  @data_file "978-1-68050-252-7.ttl"

  @doc """
  Reads default RDF model in Turtle format.
  """
  def data do
    Turtle.read_file!(@data_dir <> @data_file)
  end
end
