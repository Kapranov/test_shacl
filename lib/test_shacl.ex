defmodule TestSHACL do
  @moduledoc """
  Top-level module used in "Working with SHACL and Elixir"
  """

  alias RDF.Turtle

  @priv_dir "#{:code.priv_dir(:test_shacl)}"

  @data_dir @priv_dir <> "/data/"
  @data_file "978-1-68050-252-7.ttl"

  @shapes_dir @priv_dir <> "/shapes/"
  @shape_file "book_shape.ttl"

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
end
