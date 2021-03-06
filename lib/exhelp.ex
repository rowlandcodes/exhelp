defmodule Exhelp do
  @moduledoc """
  hello
  """

  @spec decompose(String.t()) :: module() | {module(), atom()} | mfa()
  def decompose(string) do
    string
    |> Code.string_to_quoted!()
    |> Exhelp.Helpers.decompose()
    |> Code.eval_quoted()
    |> elem(0)
  end

  defp execute([search: true, all_functions: true], _) do
    Exhelp.Search.list_all_functions()
    |> Enum.each(&IO.puts/1)
  end

  defp execute([search: true, all_modules: true], _) do
    Exhelp.Search.list_all_modules()
    |> Enum.each(&IO.puts/1)
  end

  defp execute([help: true], _) do
    display_help()
  end

  defp execute([version: true], _) do
    IO.puts(Application.spec(:exhelp)[:vsn])
  end

  defp execute([exports: true], [input]) do
    input
    |> decompose
    |> Exhelp.Helpers.print_exports()
  end

  defp execute([search: true], [input]) do
    input
    |> decompose()
    |> Exhelp.Search.search()
    |> Enum.each(&IO.puts/1)
  end

  defp execute([type: true], [input]) do
    input
    |> decompose
    |> Exhelp.Helpers.types()
  end

  defp execute([behaviour: true], [input]) do
    input
    |> decompose
    |> Exhelp.Helpers.behaviours()
  end

  defp execute([open: true], [input]) do
    input
    |> decompose
    |> Exhelp.Helpers.open()
  end

  defp execute([], [input]) do
    input
    |> decompose
    |> Exhelp.Helpers.h()
  end

  defp execute([_, _ | _], _) do
    IO.puts("exh can only use one flag at a time.")
    IO.puts("")
    display_help()
  end

  defp execute([], []) do
    display_help()
  end

  defp display_help() do
    IO.puts(~S"""
      Usage:
        exh QUERY [OPTIONS]

      Examples:
        exh Enum.map/2
        exh String -o
        exh Ecto -S mix --exports

      Options:
        QUERY                  Module, function, and/or arity 
        -o, --open             Open QUERY in an editor
        -t, --type             Displays the types defined in queried Module
        -b, --behaviour        Displays the behaviours defined in queried Module
        -s, --search           Searches for QUERY in loaded modules and exports
            --all-modules      Used with --search instead of a query.
                               Lists all modules used by loaded applications.
                               Exclusive with QUERY or --all-functions
            --all-functions    Used with --search instead of a query.
                               Lists all functions exported by modules in loaded
                               applications.
                               Exclusive with QUERY or --all-modules
            --exports          Displays the exports from queried Module
            --version          Print Exhelp version
        -S mix                 Enables mix integration allowing exh to work on 
                               project and dependency queries.
    """)
  end

  defp start_mix() do
    if exec = get_executable() do
      wrapper(fn -> Code.require_file(exec |> String.trim()) end)
    end
  end

  defp wrapper(fun) do
    _ = fun.()
    :ok
  end

  defp get_executable() do
    {path, 0} = System.cmd("elixir", ["-e", "IO.puts(System.find_executable(\"mix\"))"])
    path
  end

  def main(args) do
    {opts, args, _} =
      OptionParser.parse(args,
        strict: [
          open: :boolean,
          type: :boolean,
          behaviour: :boolean,
          script: :string,
          exports: :boolean,
          search: :boolean,
          version: :boolean,
          help: :boolean,
          all_modules: :boolean,
          all_functions: :boolean
        ],
        aliases: [b: :behaviour, t: :type, S: :script, o: :open, s: :search, h: :help]
      )

    {mix, rest} = Keyword.pop(opts, :script)
    mix_env = System.get_env("EXHELP_ENABLE_MIX") == "true"
    enable_mix = (!is_nil(mix) or mix_env) and File.regular?("mix.exs")

    if enable_mix do
      System.argv([])
      start_mix()
      System.cmd("mix", ["compile"])
    end

    IEx.configure(colors: [enabled: true])

    enable_dot_iex = System.get_env("EXHELP_ENABLE_DOT_IEX") != "false"

    if enable_dot_iex do
      load_dot_iex()
    end

    execute(rest, args)
  end

  defp load_dot_iex do
    candidates = Enum.map([".iex.exs", "~/.iex.exs"], &Path.expand/1)
    path = Enum.find(candidates, &File.regular?/1)

    if !is_nil(path) do
      eval_dot_iex(path)
    end
  end

  defp eval_dot_iex(path) do
    code = File.read!(path)
    {:ok, quoted} = Code.string_to_quoted(code)
    Code.eval_quoted(quoted)
  end
end
