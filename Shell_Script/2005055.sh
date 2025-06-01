#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Missing input file name."
    exit 1
fi

exit_func() {
    echo "Invalid input file"
    exit 1
}

trim() {
    echo "$1" | sed -e 's/^[ \t\r]*//' -e 's/[ \t\r]*$//'
}

is_integer() {
    if [[ "$1" =~ ^-?[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

is_not_integer() {
    if [[ "$1" =~ ^-?[0-9]+$ ]]; then
        return 1
    else
        return 0
    fi
}

archived_status=0
roll_upper_bound=0
roll_lower_bound=0
total_marks=0
penalty_for_unmatched=0
penalty_for_submission=0
penalty_for_plagiarism=0
allowed_code_extension=()
allowed_archive_extension=()

root="."
assignment=""
evaluate="evaluate"
issues="issues"
checked="checked"
unzipped="unzipped"
marksheet="marks.csv"
expected_output=""
plagiarism=""

create_necessary_directories() {
    IFS='/' read -ra arr <<<"$assignment"
    arr_size=${#arr[@]}
    for str in "${arr[@]}"; do
        if [ $arr_size -eq 1 ]; then
            break
        fi
        root="$root"/"$str"
        arr_size=$(($arr_size - 1))
    done
    evaluate="$root"/"$evaluate"
    issues="$root"/"$issues"
    checked="$root"/"$checked"
    unzipped="$root"/"$unzipped"
    marksheet="$root"/"$marksheet"
    assignment="$assignment"
    mkdir -p "$evaluate"
    mkdir -p "$issues"
    mkdir -p "$checked"
    mkdir -p "$unzipped"
    touch "$marksheet"
}

check_input_file() {
    file="$1"
    line_count=0
    while IFS= read -r line; do
        line_count=$(($line_count + 1))
        arr=()
        word_count_in_a_line=0
        for word in $line; do
            arr+=($word)
            word_count_in_a_line=$(($word_count_in_a_line + 1))
        done
        case $line_count in
        1)
            if [ $word_count_in_a_line -eq 1 ]; then
                val=$(trim "${arr[0]}")
                case $val in
                true)
                    archived_status=1
                    ;;
                false) ;;
                *)
                    exit_func
                    ;;
                esac
            else
                exit_func
            fi
            ;;
        2)
            if [ $archived_status -eq 1 ]; then
                if [ $word_count_in_a_line -lt 4 ]; then
                    for word in "${arr[@]}"; do
                        val=$(trim "$word")
                        case $val in
                        zip | rar | tar)
                            allowed_archive_extension+=($val)
                            ;;
                        *)
                            exit_func
                            ;;
                        esac
                    done
                else
                    exit_func
                fi
            fi
            ;;
        3)
            if [ $word_count_in_a_line -lt 5 ]; then
                for word in "${arr[@]}"; do
                    val=$(trim "$word")
                    case $val in
                    c | cpp | sh)
                        allowed_code_extension+=($val)
                        ;;
                    python)
                        allowed_code_extension+=("py")
                        ;;
                    *)
                        exit_func
                        ;;
                    esac
                done
            else
                exit_func
            fi
            ;;
        4)
            if [ $word_count_in_a_line -eq 1 ]; then
                val=$(trim "${arr[0]}")
                total_marks=$val
                if is_not_integer $val; then
                    exit_func
                fi
            else
                exit_func
            fi
            ;;
        5)
            if [ $word_count_in_a_line -eq 1 ]; then
                val=$(trim "${arr[0]}")
                penalty_for_unmatched=$val
                if is_not_integer $val; then
                    exit_func
                fi
            else
                exit_func
            fi
            ;;
        6)
            if [ $word_count_in_a_line -eq 1 ]; then
                val=$(trim "${arr[0]}")
                assignment=$val
                create_necessary_directories
            else
                exit_func
            fi
            ;;
        7)
            if [ $word_count_in_a_line -eq 2 ]; then
                val=$(trim "${arr[0]}")
                if is_not_integer $val; then
                    exit_func
                fi
                roll_lower_bound=$val
                val=$(trim "${arr[1]}")
                if is_not_integer $val; then
                    exit_func
                fi
                roll_upper_bound=$val
            else
                exit_func
            fi
            ;;
        8)
            if [ $word_count_in_a_line -eq 1 ]; then
                val=$(trim "${arr[0]}")
                expected_output="$val"
            else
                exit_func
            fi
            ;;
        9)
            if [ $word_count_in_a_line -eq 1 ]; then
                val=$(trim "${arr[0]}")
                penalty_for_submission=$val
                if is_not_integer $val; then
                    exit_func
                fi
            else
                exit_func
            fi
            ;;
        10)
            if [ $word_count_in_a_line -eq 1 ]; then
                val=$(trim "${arr[0]}")
                plagiarism="$val"
            else
                exit_func
            fi
            ;;
        11)
            if [ $word_count_in_a_line -eq 1 ]; then
                val=$(trim "${arr[0]}")
                penalty_for_plagiarism=$val
                if is_not_integer $val; then
                    exit_func
                fi
            else
                exit_func
            fi
            ;;
        esac
    done <"$file"
}

declare -A marks
declare -A marks_deducted
declare -A submission_status
declare -A remarks
declare -A has_issues
declare -A plagiarism_status

initialize_necessary_associative_array() {
    for ((roll = $roll_lower_bound; roll <= $roll_upper_bound; roll++)); do
        marks["$roll"]=0
        marks_deducted["$roll"]=0
        submission_status["$roll"]=0
        remarks["$roll"]=""
        has_issues["$roll"]=0
        plagiarism_status["$roll"]=0
    done
    while IFS= read -r line; do
        val=$(trim "$line")
        remarks["$val"]="Plagiarism detected"
        plagiarism_status["$val"]=1
    done <"$plagiarism"
}

remarks_and_deduction() {
    roll="$1"
    deduction="$2"
    add_remarks="$3"
    marks_deducted["$roll"]=$(("${marks_deducted["$roll"]}" + "$deduction"))
    if [ "${remarks["$roll"]}" == "" ]; then
        remarks["$roll"]="$add_remarks"
    else
        remarks["$roll"]=""${remarks["$roll"]}", "$add_remarks""
    fi
}

get_evaluate() {
    for file in "$assignment"/*; do
        IFS='/' read -ra arr <<<"$file"
        arr_size=${#arr[@]}
        arr_size=$(($arr_size - 1))
        file_name="${arr[$arr_size]}"
        IFS='.' read -ra brr <<<"$file_name"
        brr_size=${#brr[@]}
        roll="${brr[0]}"
        type="${brr[1]}"
        if [ $brr_size -gt 2 ]; then
            type=""${brr[1]}"."${brr[2]}""
        fi
        if is_integer $roll; then
            if
                [ $roll -ge $roll_lower_bound ] &&
                    [ $roll -le $roll_upper_bound ]
            then
                is_valid_archive_extension=0
                for archive_extension in "${allowed_archive_extension[@]}"; do
                    if [ "$type" == "$archive_extension" ]; then
                        is_valid_archive_extension=1
                    fi
                done
                is_directory=0
                if [ "$type" == "" ]; then
                    is_directory=1
                fi
                if [ $is_directory -eq 1 ]; then
                    if [ $archived_status -eq 1 ]; then
                        # penalty submission
                        remarks_and_deduction $roll $penalty_for_submission "Issue case #1"
                        has_issues["$roll"]=1
                    fi
                    mv "$file" "$evaluate"
                elif [ $is_valid_archive_extension -eq 1 ]; then
                    case $type in
                    zip)
                        unzip "$file" -d "$unzipped"
                        ;;
                    rar)
                        unrar x "$file" "$unzipped"
                        ;;
                    tar)
                        tar -xf "$file" -C "$unzipped"
                        ;;
                    esac
                    for unzipped_file in "$unzipped"/*; do
                        if [ "$unzipped_file" != "$unzipped"/"$roll" ]; then
                            mv "$unzipped_file" "$unzipped"/"$roll"
                            # penalty submission
                            remarks_and_deduction $roll $penalty_for_submission "Issue case #4"
                            has_issues["$roll"]=1
                        fi
                    done
                    for unzipped_file in "$unzipped"/*; do
                        mv "$unzipped_file" "$evaluate"
                    done
                else
                    # penalty submission
                    case $type in
                    zip | rar | tar | tar"."gz | tgz | 7z | tar"."bz2)
                        remarks_and_deduction $roll $penalty_for_submission "Issue case #2"
                        has_issues["$roll"]=1
                        mv "$file" "$issues"
                        echo $roll
                        ;;
                    *)
                        mkdir -p "$evaluate"/"$roll"
                        mv "$file" "$evaluate"/"$roll"
                        ;;
                    esac
                fi
            fi
        fi
    done
    rm -r "$unzipped"
}

evaluation() {
    for file in "$evaluate"/*; do
        IFS='/' read -ra arr <<<"$file"
        arr_size=${#arr[@]}
        arr_size=$(($arr_size - 1))
        roll="${arr[$arr_size]}"
        for code_path in "$evaluate"/"$roll"/*; do
            IFS='/' read -ra brr <<<"$code_path"
            brr_size=${#brr[@]}
            brr_size=$(($brr_size - 1))
            code="${brr[$brr_size]}"
            IFS='.' read -ra crr <<<"$code"
            file_name="${crr[0]}"
            type="${crr[1]}"
            is_valid_code_extension=0
            for code_extension in "${allowed_code_extension[@]}"; do
                if [ "$type" == "$code_extension" ]; then
                    is_valid_code_extension=1
                fi
            done
            is_valid_roll=0
            if [ "$file_name" == "$roll" ]; then
                is_valid_roll=1
            fi
            if [ $is_valid_roll -eq 1 ]; then
                submission_status["$roll"]=1
                if [ $is_valid_code_extension -eq 1 ]; then
                    output="$file/$roll"_output.txt""
                    case $type in
                    c | cpp)
                        g++ "$code_path" -o "$file"/"$roll".out""
                        "$file"/"$roll".out"" >"$output"
                        ;;
                    py)
                        python3 "$code_path" >"$output"
                        ;;
                    sh)
                        bash "$code_path" >"$output"
                        ;;
                    esac
                    # penalty mismatch
                    total_line=0
                    matched_line=0
                    while IFS= read -r expected_line; do
                        total_line=$(($total_line + 1))
                        val1=$(trim "$expected_line")
                        while IFS= read -r lines; do
                            val2=$(trim "$lines")
                            if [ "$val1" == "$val2" ]; then
                                matched_line=$(($matched_line + 1))
                                break
                            fi
                        done <"$output"
                    done <"$expected_output"
                    val=$(($total_line - $matched_line))
                    val=$(($val * $penalty_for_unmatched))
                    val=$(($total_marks - $val))
                    marks["$roll"]=$val
                else
                    # penalty submission
                    remarks_and_deduction $roll $penalty_for_submission "Issue case #3"
                    has_issues["$roll"]=1
                fi
                break
            fi
        done
        if [ "${has_issues["$roll"]}" -eq 1 ] || [ "${submission_status["$roll"]}" -eq 0 ]; then
            mv "$file" "$issues"
        elif [ "${has_issues["$roll"]}" -eq 0 ]; then
            mv "$file" "$checked"
        fi
    done
    rm -r "$evaluate"
}

write_csv() {
    echo "ID,Marks,Marks_deducted,Total_marks,Remarks" >"$marksheet"
    for ((roll = $roll_lower_bound; roll <= $roll_upper_bound; roll++)); do
        if [ "${submission_status["$roll"]}" -eq 0 ]; then
            if [ "${has_issues["$roll"]}" -eq 0 ]; then
                remarks_and_deduction $roll "0" "Missing file"
            fi
        fi
        total_marks=$(("${marks["$roll"]}" - "${marks_deducted["$roll"]}"))
        if [ "${plagiarism_status["$roll"]}" -eq 1 ]; then
            total_marks="-$penalty_for_plagiarism"
        fi
        echo "$roll,"${marks["$roll"]}","${marks_deducted["$roll"],}","$total_marks",\""${remarks["$roll"]}"\"" >>"$marksheet"
    done
}

check_input_file $1
initialize_necessary_associative_array
get_evaluate
evaluation
write_csv
