setup() {
    load '../bats-core/test/test_helper/bats-support/load'
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
    list=""
    menu list "Testing an empty list"
    assert_output ""
}

