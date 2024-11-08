defmodule AIBrainworms.SevenSegment.Predict do
  @moduledoc """
  Run single-shot inference for a trained model.

  Intended use:
  - `model` comes from `SevenSegment.Model.new/1`
  - `params` comes from `SevenSegment.Train.run/4`
  """

  alias AIBrainworms.SevenSegment.Number

  @doc """
  For a given `digit` 0-9, return the predicted class distribution under `model`.
  """
  def from_digit(model, params, digit) do
    input = Number.encode_digit!(digit) |> Nx.tensor() |> Nx.new_axis(0)
    Axon.predict(model, params, input)
  end
end
