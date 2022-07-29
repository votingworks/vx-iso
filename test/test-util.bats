setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    
    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    # make executables in src/ visible to PATH
    PATH="$DIR/../airootfs/usr/share/vx-img/:$PATH"
    echo $PATH
}

@test "Permissions on util.sh are set properly" {
    util.sh
}

@test "test empty menu list" {
    . util.sh
    list=()
    prompt="Testing an empty list"
    run menu "${list[@]}" "$prompt" 
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "test simple menu" {
    . util.sh
    list=("item")
    prompt="Select an item"
    
    run menu "${list[@]}" "$prompt" <<< 1
    assert_success

    assert_output << EndOfMessage
    1. item
    $prompt [Default: item]: 
EndOfMessage

    # Because run uses a subshell, any variables that get set don't get passed
    # back here. Run menu again without the subshell to set answer.
    menu "${list[@]}" "$prompt" <<< 1
    assert_equal $answer 1 
}
