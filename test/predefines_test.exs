defmodule PredefinesTest do
  use ExUnit.Case

  defmodule TolerantActor do
    use ExActor.Tolerant
  end

  test "tolerant" do
    {:ok, pid} = TolerantActor.start
    :gen_server.cast(pid, :undefined_message)
    send(pid, :undefined_message)
    assert match?(
      {:timeout, _}, 
      catch_exit(:gen_server.call(pid, :undefined_message, 10))
    )
  end


  defmodule NonStartableStrictActor do
    use ExActor.Strict
  end


  defmodule StrictActor do
    use ExActor.Strict, initial_state: nil
  end

  test "strict" do
    :error_logger.tty(false)

    assert match?({:error, :badinit}, NonStartableStrictActor.start)

    assert_invalid(StrictActor, &:gen_server.cast(&1, :undefined_message))
    assert_invalid(StrictActor, &send(&1, :undefined_message))
    assert_invalid(StrictActor, 
      fn(pid) ->
        assert match?(
          {{:bad_call, :undefined_message}, _}, 
          catch_exit(:gen_server.call(pid, :undefined_message, 10))
        )
      end
    )
  end

  defp assert_invalid(module, fun) do
    {:ok, pid} = module.start
    
    fun.(pid)

    :timer.sleep(20)
    assert Process.info(pid) == nil
  end



  defmodule GenServerActor do
    use ExActor.GenServer
  end

  test "gen_server" do
    :error_logger.tty(false)

    assert_invalid(GenServerActor, &:gen_server.cast(&1, :undefined_message))
    
    assert_invalid(GenServerActor,
      fn(pid) ->
        send(pid, :undefined_message)

        assert match?(
          {{:bad_call, :undefined_message}, _}, 
          catch_exit(:gen_server.call(pid, :undefined_message, 10))
        )
      end
    )
  end



  defmodule EmptyActor do
    use ExActor.Empty

    def init(args), do: { :ok, args }
    def handle_call(_msg, _from, state), do: {:reply, 1, state}
    def handle_info(_msg, state), do: {:noreply, state}
    def handle_cast(_msg, state), do: {:noreply, state}
    def terminate(_reason, _state), do: :ok
    def code_change(_old, state, _extra), do: { :ok, state }
  end

  test "empty" do
    {:ok, pid} = EmptyActor.start
    :gen_server.cast(pid, :undefined_message)
    send(pid, :undefined_message)
    assert :gen_server.call(pid, :undefined_message) == 1
  end
end