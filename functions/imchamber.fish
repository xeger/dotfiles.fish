function imchamber
  argparse --name=imchamber 'f/force' 'h/help' -- $argv 2> /dev/null
  or set _flag_h 1

  set -l argcount (count $argv)
  set -l fingerprint ""
  set -l services ""

  if test $argcount -eq 0; and test -f .chamberrc
    set -l gci_arn (aws sts get-caller-identity --output=text --query=Arn 2> /dev/null)
    if string match -q '*:assumed-role/*' $gci_arn
      set -l gci_account_id (echo $gci_arn | cut -d: -f50)
      set fingerprint "$gci_account_id"(md5 -q .chamberrc)
      set services (cat .chamberrc)
    else
      echo "imchamber: skipping (no AWS credentials available); use --force to override"
      return 0
    end
  else if test $argcount -gt 0
    for service in $argv
      set -a services "env $service"
    end
  end

  if test -n "$_flag_h"; or test -z "$services"
    echo "Usage: imchamber <service> [service2 ...]"
    echo "  - or, write .chamberrc to PWD containing `chamber` commands, one per line"
    echo ""
    echo "Exports secrets from the designated chamber service(s) to your shell environment."
    echo ""
    echo "Example .chamberrc file:"
    echo "  env service1"
    echo "  env service2"
    echo ""
    echo "Flags:"
    echo "  force - re-run chamberrc even if already run"
    return 1
  end

  if test -n "$fingerprint"; and test "$fingerprint" = "$__imchamber_last_fingerprint"; and test -z "$_flag_f"
    echo "imchamber: skipping (already ran successfully); use --force to override"
    return 0
  end

  set -l num (count $services)
  echo "imchamber: automating $num commands"

  for cmd in $services
    if not string match -qr '^\s*#|^$' $cmd # ignore comments and empty lines
      echo "+ $cmd"
      if string match -qr '^env' $cmd
        set -l cmd_suffix (string sub -s5 $cmd)
        set -l secrets_json (chamber export --format=json $cmd_suffix)
        if test $status -ne 0
          echo "imchamber: error exporting secrets from $cmd_suffix"
          return 1
        end
        set -l secrets_names (echo $secrets_json | jq -r 'keys | .[]')
        for name in $secrets_names
          set -gx (echo $name | tr a-z A-Z)  (echo $secrets_json | jq -r .$name)
        end
      else
        set -l entire_cmd "chamber $cmd"
        eval $entire_cmd
      end
    end
  end

  if test -n "$fingerprint"
    set -g __imchamber_last_fingerprint $fingerprint
  end
end
