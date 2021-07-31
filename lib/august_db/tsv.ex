defmodule TSV do
  def header_string do
    "k\tv\n"
  end

  def header_bytes do
    4
  end

  def header_kv do
    [["k", "v"]]
  end

  def row_separator do
    "\n"
  end
end
