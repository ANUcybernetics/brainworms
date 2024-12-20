defmodule Brainworms.Utils do
  @moduledoc """
  Data representation for both the 0-9 digits and the associated 7-segment bit patterns.

  There's no number data structure per. se - this module just converts (in both directions)
  between 0-9 integers (digits) and 7-element lists of 0/1 (bitlists).
  """

  @bitlists [
    # 0
    [1, 1, 1, 1, 1, 1, 0],
    # 1
    [0, 1, 1, 0, 0, 0, 0],
    # 2
    [1, 1, 0, 1, 1, 0, 1],
    # 3
    [1, 1, 1, 1, 0, 0, 1],
    # 4
    [0, 1, 1, 0, 0, 1, 1],
    # 5
    [1, 0, 1, 1, 0, 1, 1],
    # 6
    [1, 0, 1, 1, 1, 1, 1],
    # 7
    [1, 1, 1, 0, 0, 0, 0],
    # 8
    [1, 1, 1, 1, 1, 1, 1],
    # 9
    [1, 1, 1, 1, 0, 1, 1]
  ]

  @doc """
  Return the bitlist for a given digit (0-9)

  This function will raise if `digit` is not a single (0-9) digit.

      iex> Brainworms.Utils.digit_to_bitlist!(1)
      [0, 0, 1, 0, 0, 1, 0]

      iex> Brainworms.Utils.digit_to_bitlist!(5)
      [1, 1, 0, 1, 0, 1, 1]
  """
  def digit_to_bitlist(digit) when digit in 0..9 do
    Enum.at(@bitlists, digit)
  end

  @doc """
  Return the digit for a given bitlist (0-9)

  This function will raise if the bitlist doesn't correspond to a single (0-9) digit.

      iex> Brainworms.Utils.bitlist_to_digit([1, 1, 1, 1, 1, 1, 1])
      8

      iex> Brainworms.Utils.bitlist_to_digit([1, 1, 0, 1, 0, 1, 1])
      5
  """
  def bitlist_to_digit(bitlist) when is_list(bitlist) do
    Enum.find_index(@bitlists, fn bp -> bp == bitlist end)
  end

  @doc """
  Converts an integer to a 7-bit binary list representation.

  Input value is taken modulo 128 and converted to a list of 0s and 1s,
  padded to 7 bits total length.

  Useful for driving 7-segment displays, obviously :)

      iex> Brainworms.Utils.integer_to_bitlist(5)
      [0, 0, 0, 0, 1, 0, 1]

      iex> Brainworms.Utils.integer_to_bitlist(130)
      [0, 0, 0, 0, 0, 1, 0]
  """
  def integer_to_bitlist(value) when is_integer(value) do
    bitlist = value |> Integer.mod(128) |> Integer.digits(2)
    # pad out to 7 bits
    List.duplicate(0, 7 - length(bitlist)) ++ bitlist
  end

  @doc """
  Encode a list of floats as a binary string of 12-bit unsigned integers

  Input values should be floats in the range [0.0, 1.0] (if outside this
  they'll be clamped). They will be converted to 12-bit integers and packed
  into a binary string.

  This function also applies gamma correction to the values before encoding
  because of the nonlinearity of human perception of brightness.

  Useful for writing to PWM registers like on
  [this board](https://core-electronics.com.au/adafruit-24-channel-12-bit-pwm-led-driver-spi-interface-tlc5947.html).

      iex> Brainworms.Utils.pwm_encode([0, 1, 0, 1])
      <<0, 0, 255, 255, 0, 0, 255, 255>>
  """
  def pwm_encode(values) when is_list(values) do
    values
    |> Enum.map(&clamp/1)
    |> Enum.map(&gamma_correction/1)
    |> Enum.map(&((&1 * 4095.9999999999) |> trunc()))
    |> Enum.map(&<<&1::unsigned-integer-size(12)>>)
    |> Enum.reduce(<<>>, fn x, acc -> <<acc::bitstring, x::bitstring>> end)
  end

  @doc """
  Get the current system time as a float value in seconds.

  This function returns the current system time in nanoseconds as a floating-point
  value, divided by 1.0e9 to convert to seconds.

  Example:
      iex> Brainworms.Utils.float_now()
      1641234567.123456  # Value will vary based on current time
  """
  def float_now() do
    :os.system_time(:nanosecond) / 1.0e9
  end

  @doc """
  Generate a sine wave oscillator value at the current time.

  Takes a frequency in Hz and an optional phase offset in radians.
  Returns a value between -1 and 1.

  Example:
      iex> Brainworms.Utils.osc(1.0)  # Generate 1Hz sine wave
      0.5  # Value will vary based on current time
  """
  def osc(frequency, phase \\ 0.0, t \\ float_now()) do
    :math.sin(2 * :math.pi() * (t * frequency + phase))
  end

  def calculate_drift_params(drift_start_time) do
    # calculate the phases for the 7 segments so that when they start to "drift"
    # it's easy to make them drift from their current value (0 or 1)
    0..6
    # a small spread of frequencies, all very "breathy" (i.e. around 0.5Hz)
    |> Enum.map(fn x -> 0.05 + 0.01723 * x end)
    |> Enum.map(fn freq -> {freq, :math.fmod(drift_start_time, 2 + :math.pi() * freq)} end)
  end

  def apply_drift(bitlist, drift_params, t) do
    bitlist
    # add pi/2 for all the "high" bits so they start from 1, otherwise 0
    |> Enum.map(&(&1 * (:math.pi() / 2)))
    # zip with the already-calculated freq/phases for each segment
    |> Enum.zip(drift_params)
    # calculate the brightness for each segment (abs(), because it needs to be in [0, 1])
    |> Enum.map(fn {phase_offset, {freq, phase}} ->
      osc(freq, phase + phase_offset, t) |> abs()
    end)
  end

  defp gamma_correction(value) do
    gamma = 2.8
    :math.pow(value, gamma)
  end

  defp clamp(value) do
    max(0.0, min(1.0, value))
  end
end
