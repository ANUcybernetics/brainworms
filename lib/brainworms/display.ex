defmodule Brainworms.Display do
  @moduledoc """
  Handles display output through PWM controllers.
  """

  alias Brainworms.Utils

  def set(spi_bus, digit, _model) do
    # for now, just "breathe" the wires... until we can process the model properly
    c1_brightness_list = Utils.digit_to_bitlist(digit) ++ List.duplicate(1.0, 17)

    c2_brightness_list =
      Range.new(1, 24)
      |> Enum.map(fn _ -> 0.5 + 0.5 * Utils.osc(0.2) end)

    data =
      Enum.reverse(c1_brightness_list ++ c2_brightness_list ++ c2_brightness_list)
      |> Utils.pwm_encode()

    Circuits.SPI.transfer!(spi_bus, data)
  end
end
