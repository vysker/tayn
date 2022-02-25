#!/bin/zsh

export TAYN_DEFAULT_RUNTIME="docker"

function tayn_print_help {
    echo "\nUsage: tayn [command] [arguments]"
    echo "\nErgonomic container manager\n"
    echo "Command|Description|Usage
  p|List all containers|'tayn p'
  r|Restart one or more containers|'tayn r 1' or 'tayn r 3 2 1'
  s|Stop one or more containers|'tayn s 3' or 'tayn s 1 3'
  d|Delete one or more containers|'tayn d 7' or 'tayn d 4 5'
  e|Run interactive command in container|'tayn e 2 sh' for a shell session
  x|Run detached command in container|'tayn x 2 touch /tmp/abc'
  l|Show logs for container|'tayn l 5'
  i|List images|'tayn i'
    " | column --table -s "|"
    echo "\nExamples"
    echo "  'tayn s 1 2 5' stops 1st, 2nd and 5th docker container listed in 'tayn p'"
}

function tayn_get_id {
    runtime="${TAYN_RUNTIME:$TAYN_DEFAULT_RUNTIME}"
    num="$1"
    id=$($runtime ps -aq | head -$num | tail -1)
    echo $id
}

function tayn_get_name {
    runtime="${TAYN_RUNTIME:$TAYN_DEFAULT_RUNTIME}"
    id="$1"
    name=$($runtime ps -a --format "table {{.ID}}\t{{.Names}}" | grep $id | awk '{printf $2}')
    echo $name
}

function tayn {
    if [[ $# -eq 0 || $1 == "help" || $1 == "--help" || $1 == "-h" ]]; then
        tayn_print_help
        return
    fi

    cmd="$1"
    arg="$2"
    runtime="${TAYN_RUNTIME:=$TAYN_DEFAULT_RUNTIME}"

    # Split extra args into an array
    arg_count=$(($# - 1))
    if [[ $arg_count -gt 0 ]]; then
        args_raw="${@:2}" # Use args from $2 onwards
        IFS=' ' # Split on space
        read -rA args <<< "$args_raw" # Read into array variable called "args"
    fi

    # List all containers
    if [[ "$cmd" == "p" ]]; then
        $runtime ps -a --format "table {{.Names}}\t{{.Status}}" | awk '{printf "[%2s] ",NR-1}{print $0}'
        return
    fi
    
    # Restart one or more containers
    if [[ "$cmd" == "r" ]]; then
        for num in "${args[@]}";
        do
            id=$(tayn_get_id $num)
            name=$(tayn_get_name $id)
            echo "Restarting $id $name"
            $runtime restart $id
        done
        return
    fi
    
    # Stop one or more containers
    if [[ "$cmd" == "s" ]]; then
        for num in "${args[@]}";
        do
            id=$(tayn_get_id $num)
            name=$(tayn_get_name $id)
            echo "Stopping $name [$id]"
            $runtime stop $id
        done
        return
    fi

    # Delete one or more containers
    if [[ "$cmd" == "d" ]]; then
        for num in "${args[@]}";
        do
            id=$(tayn_get_id $num)
            name=$(tayn_get_name $id)
            echo "Deleting $name [$id]"
            $runtime rm $id
        done
        return
    fi

    # Run interactive command in container
    if [[ "$cmd" == "e" ]]; then
        id=$(tayn_get_id $arg)
        name=$(tayn_get_name $id)
        echo "Running '${@:3}' in $name [$id]"
        $runtime exec -it $id ${@:3}
        return
    fi

    # Run detached command in container
    if [[ "$cmd" == "x" ]]; then
        id=$(tayn_get_id $arg)
        name=$(tayn_get_name $id)
        echo "Running '${@:3}' in $name [$id]"
        $runtime exec -d $id ${@:3}
        return
    fi

    # Show logs for a container
    if [[ "$cmd" == "l" ]]; then
        id=$(tayn_get_id $arg)
        $runtime logs $id
        return
    fi

    # List images
    if [[ "$cmd" == "i" ]]; then
        if [[ "$arg_count" -eq 0 ]]; then
            $runtime images --format "table {{.Size}}\t{{.CreatedSince}}\t{{.Tag}}\t{{.Repository}}"
            return
        fi
        return
    fi

    echo "tayn: '$cmd' is not a tayn command.\nSee 'tayn help'"
}
