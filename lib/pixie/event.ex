defmodule Pixie.Event do
  defstruct client: nil, message: nil, response: nil, meta: %{}

  @moduledoc """
  This module defines the event struct, which is created for all incoming
  messages from clients and passed into the `incoming` function of extensions.

  This struct contains the following fields:
    - `:client` the PID of the `Pixie.Client` process.
    - `:message` a `Pixie.Message.*` struct, containing the incoming message.
    - `:response` a `Pixie.Response.*` struct, containing the response to be
      sent to the client.
    - `:meta` a map within which you can store arbitrary information during
      the course of extension processing.
  """
end
