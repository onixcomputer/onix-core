{ pkgs, config, ... }:
let
  gef-src = pkgs.fetchFromGitHub {
    owner = "hugsy";
    repo = "gef";
    rev = "0c95800c3ad3d99bacc153fb5ce13b4285d3d0f8";
    hash = "sha256-+6nhA8QDLfTO2c4Wry0LyIIL52PuO/R2Utqg23QMt18=";
  };

  gef-extras = pkgs.fetchFromGitHub {
    owner = "hugsy";
    repo = "gef-extras";
    rev = "954ed58c045885233e017b785ec5300960e1fbfe";
    hash = "sha256-QqyPwK8QCCJRPkX7nFN7oS5+GOIubpdNi9EIdk6/0zU=";
  };

  homeDir = config.home.homeDirectory;
in
{
  home = {
    packages = [ pkgs.gdb ];

    file = {
      # GEF python script (sourced on demand via `gef` command in .gdbinit)
      ".gdbinit-gef.py".source = "${gef-src}/gef.py";

      # .gdbinit — sensible defaults, gef loaded on demand
      ".gdbinit".text = ''
          set confirm off
        set verbose off
        set print pretty on
        set history save on
        set listsize 10
        set disassembly-flavor intel
        set height 0
        set width 0
        set auto-load safe-path /
        set breakpoint pending on

        define gef
          source ${homeDir}/.gdbinit-gef.py
        end

        define src
          layout src
        end

        define btc
          bt
          continue
        end

        define loop-stepi
          while (1)
            stepi
          end
        end

        define loop-bt
          while (1)
            bt
            continue
          end
        end

        define segfaultaddr
          p $_siginfo._sifields._sigfault.si_addr
        end

        macro define offsetof(t, f) &((t *) 0)->f
      '';

      # GEF configuration — points extras at nix store paths
      ".gef.rc".text = ''
        [context]
        clear_screen = False
        enable = True
        grow_stack_down = False
        layout = legend regs stack code args source memory threads trace extra
        nb_lines_backtrace = 10
        nb_lines_code = 6
        nb_lines_code_prev = 3
        nb_lines_stack = 8
        nb_lines_threads = -1
        peek_calls = True
        peek_ret = True
        show_registers_raw = False
        show_stack_raw = False

        [dereference]
        max_recursion = 7

        [entry-break]
        entrypoint_symbols = main _main __libc_start_main __uClibc_main start _start

        [gef]
        autosave_breakpoints_file =
        debug = False
        disable_color = False
        extra_plugins_dir = ${gef-extras}/scripts
        follow_child = True
        readline_compat = False

        [got]
        function_not_resolved = yellow
        function_resolved = green

        [heap-analysis-helper]
        check_double_free = True
        check_free_null = False
        check_heap_overlap = True
        check_uaf = True
        check_weird_free = True

        [heap-chunks]
        peek_nb_byte = 16

        [hexdump]
        always_show_ascii = False

        [highlight]
        regex = False

        [pattern]
        length = 1024

        [pcustom]
        struct_path = ${gef-extras}/structs

        [process-search]
        ps_command = ps auxww

        [theme]
        address_code = red
        address_heap = green
        address_stack = pink
        context_title_line = gray
        context_title_message = cyan
        default_title_line = gray
        default_title_message = cyan
        dereference_base_address = cyan
        dereference_code = gray
        dereference_register_value = bold blue
        dereference_string = yellow
        disassemble_current_instruction = green
        registers_register_name = blue
        registers_value_changed = bold red
        source_current_line = green
        table_heading = blue

        [trace-run]
        max_tracing_recursion = 1
        tracefile_prefix = ./gef-trace-

        [aliases]
        pf = print-format
        status = process-status
        binaryninja-interact = ida-interact
        bn = ida-interact
        binja = ida-interact
        lookup = scan
        grep = search-pattern
        xref = search-pattern
        flags = edit-flags
        sc-search = shellcode search
        sc-get = shellcode get
        ps = process-search
        start = entry-break
        nb = name-break
        ctx = context
        telescope = dereference
        pattern offset = pattern search
        hl = highlight
        highlight ls = highlight list
        hll = highlight list
        hlc = highlight clear
        highlight set = highlight add
        hla = highlight add
        highlight delete = highlight remove
        highlight del = highlight remove
        highlight unset = highlight remove
        highlight rm = highlight remove
        hlr = highlight remove
        fmtstr-helper = format-string-helper
        screen-setup = tmux-setup
      '';
    };
  };
}
