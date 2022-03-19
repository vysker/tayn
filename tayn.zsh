#!/bin/zsh

export TAYN_DEFAULT_RUNTIME="docker"

function tayn_print_compose_commands {
    echo "Command|Description|Usage
  p, ps|List all services|'tayn c p'
  u, up|Run any or all services|'tayn c u' or 'tayn c u redis 2 postgres'
  s, stop|Stop any or all services|'tayn c s' or 'tayn c s redis'
" | column --table -s "|"
}

function tayn_print_commands {
    echo "Command|Description|Usage
  p, ps|List all containers|'tayn p'
  r, restart|Restart one or more containers|'tayn r 1' or 'tayn r 3 2 1'
  s, stop|Stop one or more containers|'tayn s 3' or 'tayn s 1 3'
  d, delete|Delete one or more containers|'tayn d 7' or 'tayn d 4 5'
  e, session|Run interactive command in container|'tayn e 2 sh'
  x, exec|Run detached command in container|'tayn x 2 touch /tmp/abc'
  l, logs|Show logs for container|'tayn l 5'
  c, compose|Run docker compose commands|'tayn c help'
  t, top|Show stats|'tayn t'
  i, image|List images|'tayn i'
" | column --table -s "|"
}

function tayn_print_help {
    echo "\nUsage: tayn [command] [arguments]"
    echo "\nErgonomic container manager\n"
    tayn_print_commands
    echo "\nExamples"
    echo "  'tayn s 1 2 5' stops 1st, 2nd and 5th docker container listed in 'tayn p'"
}

function tayn_get_runtime {
    runtime="${TAYN_RUNTIME:$TAYN_DEFAULT_RUNTIME}"
    echo $runtime
}

function tayn_compose_ps {
    docker-compose ps | awk -F' {2,}' '{printf "[%2s] %s|%s\n",NR-1,$3,$4}' | column --table -s "|"
}

function tayn_compose_get_service {
    num="$1"
    # 'grep "$num]"', because we list our docker services with "[ 1]"
    # 'cut -c 5-', because we want to cut off the "[ 1]" part (cut==substring)
    service=$(tayn_compose_ps | grep "$num]" | cut -c 5- | awk '{print $1}')
    echo $service
}

function tayn_get_id {
    runtime=$(tayn_get_runtime)
    num="$1"
    id=$($runtime ps -aq | head -$num | tail -1)
    echo $id
}

function tayn_get_name {
    runtime=$(tayn_get_runtime)
    id="$1"
    name=$($runtime ps -a --format "table {{.ID}}\t{{.Names}}" | grep $id | awk '{printf $2}')
    echo $name
}

function tayn_ps {
    runtime=$(tayn_get_runtime)
    $runtime ps -a --format "table {{.Names}}\t{{.Status}}" | awk '{printf "[%2s] ",NR-1}{print $0}'
}

# Docker compose
function tayn_compose {
    cmd="$2" # Docker compose command

    if [[ "$#" -lt 2 || "$cmd" == "help" || "$cmd" == "--help" || "$cmd" == "-h" ]]; then
        tayn_print_compose_commands
        return
    fi

    if [[ "$cmd" == "p" || "$cmd" == "ps" ]]; then
        # awk -F' {2,}' means: 'only split on 2 or more spaces'
        docker-compose ps | awk -F' {2,}' '{printf "[%2s] %s|%s\n",NR-1,$3,$4}' | column --table -s "|"
        return
    fi

    if [[ "$cmd" == "u" || "$cmd" == "up" ]]; then
        for arg in "${@:3}";
        do
            # If the argument is a string, simply run 'docker-compose up' with that service name.
            # If the argument is a number, look up the corresponding service name first.
            # That way, we can mix our commands like this: 'tayn c u redis 2 postgres'
            case $arg in
                (*[!0-9]*'') docker-compose up $arg -d;;
                (*) service=$(tayn_compose_get_service $arg); docker-compose up $service -d;;
            esac
        done
        if [[ -z "${@:3}" ]]; then
            docker-compose up -d
        fi
        # docker-compose up ${@:3} -d
        return
    fi

    if [[ "$cmd" == "s" || "$cmd" == "stop" ]]; then
        for arg in "${@:3}";
        do
            # If the argument is a string, simply run 'docker-compose stop' with that service name.
            # If the argument is a number, look up the corresponding service name first.
            # That way, we can mix our commands like this: 'tayn c s redis 2 postgres'
            case $arg in
                (*[!0-9]*'') docker-compose stop $arg;;
                (*) service=$(tayn_compose_get_service $arg); docker-compose stop $service;;
            esac
        done
        if [[ -z "${@:3}" ]]; then
            docker-compose stop
        fi
        # docker-compose stop ${@:3}
        return
    fi

    echo "tayn: '$cmd' is not a docker-compose command.\nSee 'tayn help'"
    return
}

function tayn {
    # Resetting variables is necessary because zsh remembers
    cmd=
    arg=
    args=
    arg_count=
    args_array=
    service=
    runtime="${TAYN_RUNTIME:=$TAYN_DEFAULT_RUNTIME}"

    if [[ $1 == "help" || $1 == "--help" || $1 == "-h" ]]; then
        tayn_print_help
        return
    fi

    if [[ $# -eq 0 ]]; then
        tayn_print_commands
        echo ""
        vared -p "Choose a command (p/r/s/d/e/x/l/i): " -c cmd
        echo ""

        if [[ "$cmd" == "p" || "$cmd" == "i" ]]; then
        else
            # TODO: Store the result of "ps" and use it when executing commands, because the result of "ps" can change while the user is selecting containers
            tayn_ps
            echo ""
            vared -p "Select containers: " -c args
            echo ""
        fi
    else
        cmd="$1"
        args="${@:2}" # Use args from $2 onwards
    fi

    # Split extra args into an array
    IFS=' ' # Split on space
    read -rA args_array <<< "$args" # Read into array variable called "args_array"

    # List all containers
    if [[ "$cmd" == "p" || "$cmd" == "ps" ]]; then
        tayn_ps
        return
    fi
    
    # Restart one or more containers
    if [[ "$cmd" == "r" || "$cmd" == "restart" ]]; then
        echo "Restarting:"
        ids=()
        for num in "${args_array[@]}";
        do
            id=$(tayn_get_id $num)
            name=$(tayn_get_name $id)
            echo "- $id: $name"
            ids+=($id)
        done
        echo ""
        $runtime restart "${ids[@]}"
        return
    fi
    
    # Stop one or more containers
    if [[ "$cmd" == "s" || "$cmd" == "stop" ]]; then
        echo "Stopping:"
        ids=()
        for num in "${args_array[@]}";
        do
            id=$(tayn_get_id $num)
            name=$(tayn_get_name $id)
            echo "- $id: $name"
            ids+=($id)
        done
        echo ""
        $runtime stop "$ids"
        return
    fi

    # Delete one or more containers
    if [[ "$cmd" == "d" || "$cmd" == "delete" ]]; then
        echo "Deleting:"
        ids=()
        for num in "${args_array[@]}";
        do
            id=$(tayn_get_id $num)
            name=$(tayn_get_name $id)
            echo "- $id: $name"
            ids+=($id)
        done
        echo ""
        $runtime rm "$ids"
        return
    fi

    # Run interactive command in container
    if [[ "$cmd" == "e" || "$cmd" == "session" ]]; then
        id=$(tayn_get_id $2)
        name=$(tayn_get_name $id)
        echo "Running '${@:3}' in $id: $name"
        $runtime exec -it $id ${@:3}
        return
    fi

    # Run detached command in container
    if [[ "$cmd" == "x" || "$cmd" == "exec" ]]; then
        id=$(tayn_get_id $2)
        name=$(tayn_get_name $id)
        echo "Running '${@:3}' in $id: $name"
        $runtime exec -d $id ${@:3}
        return
    fi

    # Show logs for a container
    if [[ "$cmd" == "l" || "$cmd" == "logs" ]]; then
        id=$(tayn_get_id $args)
        $runtime logs $id
        return
    fi

    if [[ "$cmd" == "c" || "$cmd" == "compose" ]]; then
        tayn_compose $@
        return
    fi

    # List images
    if [[ "$cmd" == "i" || "$cmd" == "image" ]]; then
        if [[ "$arg_count" -eq 0 ]]; then
            $runtime images --format "table {{.Size}}\t{{.CreatedSince}}\t{{.Tag}}\t{{.Repository}}"
            return
        fi
        return
    fi

    # Show stats
    if [[ "$cmd" == "t" || "$cmd" == "top" ]]; then
        $runtime stats
        return
    fi


    echo "tayn: '$cmd' is not a tayn command.\nSee 'tayn help'"
}
