setup() {
    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    # make executables in src/ visible to PATH
    PATH="$DIR/../airootfs/usr/share/vx-img/:$PATH"
    echo $PATH
}

@test "can run our script" {
    # notice the missing ./
    # As we added src/ to $PATH, we can omit the relative path to `src/project.sh`.
    scrape-image.sh
}


