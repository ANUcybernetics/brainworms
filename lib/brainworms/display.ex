defmodule Brainworms.Display do
  @moduledoc """
  Handles display output through PWM controllers.
  """

  alias Brainworms.Utils
  alias Brainworms.Knob

  @pwm_controller_count 3

  @pin_mapping %{
    ss: 62,
    dense_0: 48,
    # dense_1 is split into two parts, and the layer weights & final softmax outputs are interleaved
    dense_1_and_output_a: 0,
    dense_1_and_output_b: 24,
    relu_0a: 15,
    relu_0b: 39
  }

  def set(spi_bus, activations) do
    # pull out the easy ones
    [input, dense_0, [relu_0a, relu_0b], dense_1, softmax_0] = activations

    {dense_1_and_output_a, dense_1_and_output_b} =
      dense_1
      |> Enum.chunk_every(2)
      |> Enum.zip_with(softmax_0, fn weights, output -> weights ++ [output] end)
      |> List.flatten()
      |> Enum.split(15)

    data =
      List.duplicate(0, 24 * @pwm_controller_count)
      |> replace_sublist(@pin_mapping.ss, input)
      |> replace_sublist(@pin_mapping.dense_0, dense_0)
      |> replace_sublist(@pin_mapping.dense_1_and_output_a, dense_1_and_output_a)
      |> replace_sublist(@pin_mapping.dense_1_and_output_b, dense_1_and_output_b)
      |> replace_sublist(@pin_mapping.relu_0a, relu_0a)
      |> replace_sublist(@pin_mapping.relu_0b, relu_0b)

    # TODO need to light the wires based on model_state

    Circuits.SPI.transfer!(spi_bus, data)
  end

  @doc """
  Demonstrates breathing effect on LED display by applying oscillating PWM values.
  Takes current knob position as input to determine seven segment display pattern,
  then applies a breathing pattern across all other controllers.

  Params:
    spi_bus: The SPI bus instance for communication with PWM controllers
  """
  def breathe_demo(spi_bus) do
    seven_segment = Knob.bitlist()

    data =
      Range.new(1, 24 * @pwm_controller_count)
      |> Enum.map(fn x -> 0.5 + 0.5 * Utils.osc(0.1 * 0.5 * Integer.mod(x, 19)) end)
      |> replace_sublist(@pin_mapping.ss, seven_segment)
      |> Utils.pwm_encode()

    Circuits.SPI.transfer!(spi_bus, data)
  end

  @doc """
  Demonstrates a step pattern by moving a single off LED around the display.

  Params:
    spi_bus: The SPI bus instance for communication with PWM controllers
  """
  def step_demo(spi_bus) do
    second = System.os_time(:second) |> Integer.mod(24 * @pwm_controller_count)

    data =
      List.duplicate(1, 24 * @pwm_controller_count)
      |> List.replace_at(second, 0)
      |> Utils.pwm_encode()

    Circuits.SPI.transfer!(spi_bus, data)
  end

  @doc """
  Sets all PWM channels to a specified value.

  Params:
    spi_bus: The SPI bus instance for communication with PWM controllers
    value: Value to set all PWM channels to between 0 and 1
  """
  def set_all(spi_bus, value) do
    data =
      value
      |> List.duplicate(24 * @pwm_controller_count)
      |> Utils.pwm_encode()

    Circuits.SPI.transfer!(spi_bus, data)
    :ok
  end

  def replace_sublist(list, start_index, new_sublist) do
    Enum.take(list, start_index) ++
      new_sublist ++
      Enum.drop(list, start_index + length(list))
  end
end
