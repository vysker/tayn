#!/bin/zsh

export TAYN_DEFAULT_RUNTIME="docker"

function tayn_print_compose_commands {
    echo "Command|Description|Usage
  p, ps|List all services|'tayn c p'
  u, up|Run any or all services|'tayn c u' or 'tayn c u redis postgres'
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

function tayn {
    # Resetting variables is necessary because zsh remembers
    cmd=
    args=
    arg_count=
    args_array=
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
        for num in "${args_array[@]}";
        do
            id=$(tayn_get_id $num)
            name=$(tayn_get_name $id)
            echo "Restarting $id $name"
            $runtime restart $id
        done
        return
    fi
    
    # Stop one or more containers
    if [[ "$cmd" == "s" || "$cmd" == "stop" ]]; then
        for num in "${args_array[@]}";
        do
            id=$(tayn_get_id $num)
            name=$(tayn_get_name $id)
            echo "Stopping $name [$id]"
            $runtime stop $id
        done
        return
    fi

    # Delete one or more containers
    if [[ "$cmd" == "d" || "$cmd" == "delete" ]]; then
        for num in "${args_array[@]}";
        do
            id=$(tayn_get_id $num)
            name=$(tayn_get_name $id)
            echo "Deleting $name [$id]"
            $runtime rm $id
        done
        return
    fi

    # Run interactive command in container
    if [[ "$cmd" == "e" || "$cmd" == "session" ]]; then
        id=$(tayn_get_id $args)
        name=$(tayn_get_name $id)
        echo "Running '${@:3}' in $name [$id]"
        $runtime exec -it $id ${@:3}
        return
    fi

    # Run detached command in container
    if [[ "$cmd" == "x" || "$cmd" == "exec" ]]; then
        id=$(tayn_get_id $args)
        name=$(tayn_get_name $id)
        echo "Running '${@:3}' in $name [$id]"
        $runtime exec -d $id ${@:3}
        return
    fi

    # Show logs for a container
    if [[ "$cmd" == "l" || "$cmd" == "logs" ]]; then
        id=$(tayn_get_id $args)
        $runtime logs $id
        return
    fi

    # Docker compose
    if [[ "$cmd" == "c" || "$cmd" == "compose" ]]; then
        dc_cmd="$2" # Docker compose command
        if [[ "$dc_cmd" == "help" || "$dc_cmd" == "--help" || "$dc_cmd" == "-h" ]]; then
            tayn_print_compose_commands
            return
        fi
        if [[ "$dc_cmd" == "p" || "$dc_cmd" == "ps" ]]; then
            docker-compose ps
            return
        fi
        if [[ "$dc_cmd" == "u" || "$dc_cmd" == "up" ]]; then
            docker-compose up ${@:3} -d
            return
        fi
        if [[ "$dc_cmd" == "s" || "$dc_cmd" == "stop" ]]; then
            docker-compose stop ${@:3}
            return
        fi
        echo "tayn: '$dc_cmd' is not a docker-compose command.\nSee 'tayn help'"
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
