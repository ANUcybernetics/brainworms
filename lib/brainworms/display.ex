defmodule Brainworms.Display do
  @moduledoc """
  Handles display output through PWM controllers.
  """

  alias Brainworms.Utils

  @pwm_controller_count 3

  @pin_mapping %{
    ss: 62,
    dense_0: 48,
    # dense_1 is split into two parts, and the layer weights & final softmax outputs are interleaved
    dense_1_and_output_a: 0,
    dense_1_and_output_b: 24,
    hidden_0a: 15,
    hidden_0b: 39
  }

  def set(spi_bus, activations) do
    # pull out the easy ones
    [seven_segment, dense_0, [hidden_0a, hidden_0b], dense_1, output] =
      scale_activations(activations)

    {dense_1_and_output_a, dense_1_and_output_b} =
      dense_1
      |> Enum.chunk_every(2)
      |> Enum.zip_with(output, fn weights, output -> weights ++ [output] end)
      |> List.flatten()
      |> Enum.split(15)

    data =
      List.duplicate(0, 24 * @pwm_controller_count)
      |> replace_sublist(@pin_mapping.ss, seven_segment)
      |> replace_sublist(@pin_mapping.dense_0, dense_0)
      |> replace_sublist(@pin_mapping.dense_1_and_output_a, dense_1_and_output_a)
      |> replace_sublist(@pin_mapping.dense_1_and_output_b, dense_1_and_output_b)
      |> replace_sublist(@pin_mapping.hidden_0a, [hidden_0a])
      |> replace_sublist(@pin_mapping.hidden_0b, [hidden_0b])
      # it's a big'ol shift register, so we need to send the bits in reverse
      |> Enum.reverse()
      |> Utils.pwm_encode()

    Circuits.SPI.transfer!(spi_bus, data)
  end

  @doc """
  Demonstrates breathing effect on LED display by applying oscillating PWM values.
  Takes current knob position as input to determine seven segment display pattern,
  then applies a breathing pattern across all other controllers.

  Params:
    spi_bus: The SPI bus instance for communication with PWM controllers
  """
  def breathe_demo(spi_bus, seven_segment) do
    data =
      Range.new(1, 24 * @pwm_controller_count)
      |> Enum.map(fn x -> 0.5 + 0.5 * Utils.osc(0.1 * 0.5 * Integer.mod(x, 19)) end)
      |> replace_sublist(@pin_mapping.ss, seven_segment)
      # it's a big'ol shift register, so we need to send the bits in reverse
      |> Enum.reverse()
      |> Utils.pwm_encode()

    Circuits.SPI.transfer!(spi_bus, data)
  end

  @doc """
  Show a demo by flashing through the layers of the network.

  Params:
    spi_bus: The SPI bus instance for communication with PWM controllers
  """
  def layer_demo(spi_bus) do
    layer = System.os_time(:second) |> Integer.mod(4)
    zeroes = List.duplicate(0, 24 * @pwm_controller_count)

    data =
      case layer do
        0 ->
          replace_sublist(zeroes, @pin_mapping.ss, List.duplicate(1, 7))

        1 ->
          replace_sublist(zeroes, @pin_mapping.dense_0, List.duplicate(1, 14))

        2 ->
          zeroes
          |> replace_sublist(@pin_mapping.hidden_0a, [1])
          |> replace_sublist(@pin_mapping.hidden_0b, [1])

        3 ->
          zeroes
          |> replace_sublist(@pin_mapping.dense_1_and_output_a, List.duplicate(1, 15))
          |> replace_sublist(@pin_mapping.dense_1_and_output_b, List.duplicate(1, 15))
      end
      # it's a big'ol shift register, so we need to send the bits in reverse
      |> Enum.reverse()
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
      # it's a big'ol shift register, so we need to send the bits in reverse
      |> Enum.reverse()
      |> Utils.pwm_encode()

    Circuits.SPI.transfer!(spi_bus, data)
  end

  @doc """
  Sets a single PWM channel to a specified value.

  Params:
    spi_bus: The SPI bus instance for communication with PWM controllers
    index: Index of the PWM channel to set (0-71)
    value: Value to set the PWM channel to between 0 and 1
  """
  def set_one(spi_bus, index, value) do
    data =
      List.duplicate(0, 24 * @pwm_controller_count)
      |> List.replace_at(index, value)
      # it's a big'ol shift register, so we need to send the bits in reverse
      |> Enum.reverse()
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
      Enum.drop(list, start_index + length(new_sublist))
  end

  def scale_activations(activations) do
    [input, dense_0, hidden_0, dense_1, output] = activations

    [
      input,
      scale_to_0_1(dense_0),
      # scale the ReLU units (which will always be > 0) to approach 1 as they get large
      Enum.map(hidden_0, fn x -> x / (1 + x) end),
      scale_to_0_1(dense_1),
      output
    ]
  end

  defp scale_to_0_1(brightness_list) do
    min_value = Enum.min(brightness_list)
    max_value = Enum.max(brightness_list)
    range = max_value - min_value

    if range == 0 do
      List.duplicate(0, length(brightness_list))
    else
      Enum.map(brightness_list, fn x -> (x - min_value) / range end)
    end
  end
end
