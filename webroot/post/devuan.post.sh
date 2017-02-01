#!/usr/bin/env bash

# Always run from root.
cd /root

# Log output to external log.
exec > >(tee -i postinst.log)
exec 2>&1

# report(<message_text>...)
# Prints.
#
# Print <message_text>s with standard framing text.
#
function report { printf "$*\n" ; }
function reportApplication { report "postinst: $*" ; }
function reportInfo { reportApplication "Info: $*" ; }
function reportWarning { reportApplication "Warning: $*" >&2 ; }
function reportError { reportApplication "Error: ${FUNCNAME[1]}(): $*" >&2 ; }
function reportDebug {
    [ ! "$debug" -o  "$debug" = 0 ] && return
    typeset msg
    msg="Debug: ${FUNCNAME[1]}(): $*"
    reportApplication "$msg" >&2
    [ ! "$logfile" ] || printf "%s\n" "$msg" >> "$logfile"
}

# parseParameters(<parameters>)
# Sets variables.
#
# Parse command-line parameters <parameters> for options.
#
# For each command-line option "--foo" or "--foo=bar" set variable
# foo either to "1" or, respectively, to "bar".
#
# Optionally supports a $mandatories and a $optionals list, which allows
# validity and scope checking.
#
# Example: mandatories="foo bar" ; optionals="baz" ; parseParameters "$@"
# (As shown in the example, $@ must be enclosed in double quotation marks.)
#
# Warning: arguments starting with '--' will be interpreted as options,
# so do not send to this function non-option arguments which could
# start with '--'
#
# Option values may be arbitrary strings.
# Option names may not contain spaces.
#
function parseParameters {
    typeset -a variables
    typeset -a values
    typeset -i indx
    typeset -i numVariables
    typeset found
    typeset mandatoriesMissing
    typeset optionalsOmitted
    typeset illegalsPresent
    typeset parameter
    typeset variable
    typeset mandatory
    typeset optional
    typeset value

    # First omit any non-option parameters
    while [ "$1" ]; do
        case "$1" in
          --*)
            # Found the first well formed option.
            break
            ;;
          *)
            # Not a well formed option.  Next!
            reportWarning "Unrecognized parameter $1"
            shift
            ;;
        esac
    done

    # From options extract variables;
    # i.e., strings between initial "--" and either first "=" or eol
    let indx=0
    typeset IFS=" "
    for parameter in "$@" ; do
        parameterWithoutHyphens="${parameter#--}"
        if [ "$parameterWithoutHyphens" = "$parameter" ]; then
            # Not a well-formed option
            reportWarning "Unrecognized parameter $parameter"
            continue
        fi
        case "$parameterWithoutHyphens" in
          *=*)
            variable="${parameterWithoutHyphens%%=*}"
            value="${parameterWithoutHyphens#$variable=}"
            ;;
          *)
            variable="$parameterWithoutHyphens"
            value=1  # Default value
            ;;
        esac
        variables[indx]="$variable"
        values[indx]="$value"
        let indx+=1
    done
    let numVariables=indx
    reportDebug "Variables=${variables[*]}, Values=${values[*]}"

    # Check that mandatories are present
    mandatoriesMissing=""
    for mandatory in $mandatories ; do
        found=""  # (False)
        for variable in "${variables[@]}" ; do
            if [ "$variable" = "$mandatory" ]; then
                found="y"
                break
            fi
        done
        [ "$found" ] || mandatoriesMissing="${mandatoriesMissing:+$mandatoriesMissing }--$mandatory"
    done

    if [ ! "$silence" ]; then
        optionalsOmitted=""
        # Check that optionals are present
        for optional in $optionals ; do
            found=""  # (False)
            for variable in "${variables[@]}" ; do
                if [ "$variable" = "$optional" ]; then
                    found="y"
                    break
                fi
            done
            [ "$found" ] || optionalsOmitted="${optionalsOmitted:+$optionalsOmitted }--$optional"
        done
    fi

    # Set variables (if legal)
    if [ "$mandatories" -o "$optionals" ]; then
        acceptAllVariables=""  # (False)
        legalVariables=" $mandatories $optionals " # With initial, intermediate and final space!
    else
        # No mandatories or optionals specified
        # Accept any variable (extremely unsafe)
        acceptAllVariables="y"
    fi

    let indx=0
    while [[ indx -lt numVariables ]]; do
        variable="${variables[indx]}"
        if [ "$acceptAllVariables" ] || [[ "$legalVariables" =~ " $variable " ]]; then
            value="${values[indx]}"
            reportDebug "Setting variable \"$variable\" with value: \"$value\""
            export "$variable"="$value"
        else
            illegalsPresent="${illegalsPresent:+$illegalsPresent }--$variable"
        fi
        let indx+=1
    done


    if [ "$illegalsPresent" ]; then
        reportError "Illegal parameter(s): $illegalsPresent"
    fi

    if [ "$mandatoriesMissing" ]; then
        reportError "Mandatory parameter(s) missing: $mandatoriesMissing"
    fi

    if [ ! "$silence" ] && [ "$optionalsOmitted" ]; then
        reportInfo "Optional parameter(s) omitted: $optionalsOmitted"
    fi

    if [ "$illegalsPresent" ] || [ "$mandatoriesMissing" ]; then
        exit 1
    fi

    # Unset extra parameters to this function
    unset mandatories
    unset optionals
    unset silence
}

function doPostInstallation {
    reportInfo "Updating package list and installing latest updates"
    apt-get update
    apt-get -y dist-upgrade

    reportInfo "Installing additional software components"
    apt-get -y install linux-headers-$(uname -r) sudo

    reportInfo "Installing and configuring VMware Tools component"
    apt-get -y install open-vm-tools
    mkdir -p /mnt/hgfs
    echo -n ".host:/ /mnt/hgfs vmhgfs rw,ttl=1,uid=my_uid,gid=my_gid,nobootwait 0 0" >> /etc/fstab

    reportInfo "Configuring sudo"
    usermod -G sudo -a vagrant
    sed -i -e '/Defaults\s\+env_reset/a Defaults\texempt_group=sudo' /etc/sudoers
    sed -i -e 's/%sudo  ALL=(ALL:ALL) ALL/%sudo ALL=NOPASSWD:ALL/g' /etc/sudoers

    reportInfo "Configuring ssh"
    echo "UseDNS no" >> /etc/ssh/sshd_config

    reportInfo "Setting up public keys using pkctl"
    wget $baseurl/auth/pkctl.sh -O pkctl.sh -q
    bash pkctl.sh auto --url=$baseurl/auth

    reportInfo "Removing account passwords (only ssh key login enabled)"
    passwd -d root
    passwd -d vagrant

    reportInfo "Cleaning up"
    apt-get -y autoremove
    apt-get -y clean
    rm -f /var/lib/dhcp/*
    rm -f /etc/udev/rules.d/70-persistent-net.rules
    rm -rf /dev/.udev/
    rm -f /lib/udev/rules.d/75-persistent-net-generator.rules
}

# printVersion()
# Prints.
#
# Prints the version of session.
#
function printVersion {
    echo "postinst 0.2"
}

# printUsageText()
# Prints.
#
# Prints help text .
#
function printUsageText {
  printf "%s\n" "\
    Usage: $0 apply|version|help

    Commands:
    apply       - apply the post installation configuration to this system.
    version     - show version.
    help        - show this help message.

    Arguments for apply:
    --baseurl   - the htpp base url of the upstream configuration location.

    Generic arguments:
    --debug     - pass this to enable debug mode. no value required.
    " | sed 's/^[[:space:]]*//'

}

# Main case statement.
main="$1"
case "$main" in
  apply)
    shift 1
    mandatories="baseurl" optionals="debug" silence="true" parseParameters "$@"
    doPostInstallation
    exit $?
    ;;
  version|--version|-v)
    printVersion
    exit $?
    ;;
  help|--help|-h)
    printUsageText
    exit $?
    ;;
  *)
    printUsageText
    exit 1
    ;;
esac
