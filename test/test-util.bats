setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    
    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    # make executables in src/ visible to PATH
    PATH="$DIR/../airootfs/usr/share/vx-img/:$PATH"

    # shellcheck source=util.sh
    source util.sh
}

@test "test int function" {

    res=$(int "1")
    assert_equal "$res" 1

    res=$(int "asdf")
    assert_equal "$res" ""
}

@test "test mocked lsblk" {
    function lsblk {
    cat << EOM
sda1   507510784 part
vda2 20955791360 part
vda  21474836480 disk
EOM
    }
    run lsblk
expected="sda1   507510784 part
vda2 20955791360 part
vda  21474836480 disk"
    assert_output "$expected"
}

@test "Permissions on util.sh are set properly" {
    util.sh
}

@test "test empty menu list" {
    list=()
    prompt="Testing an empty list"
    run menu "${list[@]}" "$prompt" 
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "test simple menu" {
    list=("item")
    prompt="Select an item"
    
    run menu "${list[@]}" "$prompt" <<< 1
    assert_success

    expected="1. item
$prompt Default: [item]" 
    assert_output "$expected"

    # Because run uses a subshell, any variables that get set don't get passed
    # back here. Run menu again without the subshell to set answer.
    menu "${list[@]}" "$prompt" <<< 1
    assert_equal "$answer" 1 
}

@test "test complex menu" {
    list=("item1" "item2")
    prompt="Select an item"
    
    run menu "${list[@]}" "$prompt" <<< 1
    assert_success

    expected="1. item1
2. item2
$prompt Default: [item2]"
    assert_output "$expected"

    # Because run uses a subshell, any variables that get set don't get passed
    # back here. Run menu again without the subshell to set answer.
    menu "${list[@]}" "$prompt" <<< 1
    assert_equal "$answer" 1 

    menu "${list[@]}" "$prompt" <<< 2
    assert_equal "$answer" 2 
}

@test "test complex menu bad selection" {
    list=("item1" "item2")
    prompt="Select an item"
    
    run menu "${list[@]}" "$prompt" <<< 1
    assert_success

    expected="1. item1
2. item2
$prompt Default: [item2]"
    assert_output "$expected"

    # Because run uses a subshell, any variables that get set don't get passed
    # back here. Run menu again without the subshell to set answer.
    menu "${list[@]}" "$prompt" <<< 1
    assert_equal "$answer" 1 

    menu "${list[@]}" "$prompt" <<< "x"
    assert_equal "$answer" "x" 
}
@test "test disk select one disk" {
    prompt="Which disk would you like to select?"
    run disk_select "$prompt" <<< 1
    assert_success

    disk_select "$prompt" <<< 1
    assert_equal "$_diskname" "vda"
    assert_equal "$_datadisk" "/dev/vda"
}


@test "test disk select no disk" {
    function lsblk {
        echo ""
    }
    prompt="Which disk would you like to select?"
    run disk_select "$prompt" <<< 1
    assert_failure
    assert_output "There are no compatible disks!"
}

@test "test disk select two disks" {
    function lsblk {
    cat << EOM
sda    507510784 disk
sda1   507510784 part
vda2 20955791360 part
vda  21474836480 disk
EOM
    }
    prompt="Which disk would you like to select?"
    run disk_select "$prompt" <<< 1
    assert_success
    expected="1. sda
2. vda
$prompt Default: [vda]"
    assert_output "$expected" 

    unset _diskname
    unset _datadisk

    disk_select "$prompt" <<< 1
    assert_equal "$_diskname" "sda"
    assert_equal "$_datadisk" "/dev/sda"

    unset _diskname
    unset _datadisk
    disk_select "$prompt" <<< 2
    assert_equal "$_diskname" "vda"
    assert_equal "$_datadisk" "/dev/vda"
    unset _diskname
    unset _datadisk

    disk_select "$prompt" <<< "" 
    assert_equal "$_diskname" "vda"
    assert_equal "$_datadisk" "/dev/vda"
}

# This test is broken because of the clear command. I'm not totally sure how to
# make it work.
@test "test disk_select two disks bad selection" {
    function lsblk {
    cat << EOM
sda    507510784 disk
sda1   507510784 part
vda2 20955791360 part
vda  21474836480 disk
EOM
    }
    prompt="Which disk would you like to select?"
    run $(disk_select "$prompt" <<< "a" > /dev/null)
    assert_success

    output=$(disk_select "$prompt" <<< "a")
    expected="1. sda
2. vda
$prompt Default: [vda]
Invalid selection, starting over
1. sda
2. vda
$prompt Default: [vda]"

    # because our output has special control codes in it (produced by clear),
    # we have to strip them out for the string comparison to work properly
    output="${$output//\[H\[2J\[3J/}"
    assert_equal "$output" "$expected"

    unset _diskname
    unset _datadisk
    disk_select "$prompt" <<< "aasdfasdfa
1"  > /dev/null

    echo "$_diskname"
    # vda is chosen here because it is the default. When the program receives
    # the end of input that's what it picks. 
    assert_equal "$_diskname" "sda"
    assert_equal "$_datadisk" "/dev/sda"
}
