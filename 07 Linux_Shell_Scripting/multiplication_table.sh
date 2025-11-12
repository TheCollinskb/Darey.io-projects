#!/bin/bash

# multiplication_table.sh
# A professional-grade multiplication table generator with full/partial range support
# Bonus: Repeat loop + Display style selection

# Colors for better UX
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    printf "${!1}%s${NC}\n" "$2"
}

# Function to validate if input is a positive integer
is_positive_integer() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 0 ]
}

# Function to display the multiplication table
display_table() {
    local num=$1
    local start=$2
    local end=$3
    local style=$4

    case $style in
        1)  # Classic: 5 x 3 = 15
            for ((i=start; i<=end; i++)); do
                printf "%3d x %2d = %3d\n" "$num" "$i" $((num * i))
            done
            ;;
        2)  # Grid Style with borders
            printf "${BLUE}+-----------------+\n"
            printf "| %3s x %2s = %3s |\n" "$num" "i" "Result"
            printf "+-----------------+\n${NC}"
            for ((i=start; i<=end; i++)); do
                printf "${GREEN}| %3d x %2d = %3d |${NC}\n" "$num" "$i" $((num * i))
            done
            printf "${BLUE}+-----------------+\n${NC}"
            ;;
        3)  # Minimal: 5*3=15
            for ((i=start; i<=end; i++)); do
                printf "%d*%d=%d " "$num" "$i" $((num * i))
            done
            echo
            ;;
    esac
}

# Main program loop
while true; do
    clear
    print_color "BLUE" "=================================="
    print_color "YELLOW" "   MULTIPLICATION TABLE GENERATOR"
    print_color "BLUE" "=================================="
    echo

    # Step 1: Get the base number
    while true; do
        read -p "Enter the number for the multiplication table: " base_num
        if [[ -z "$base_num" ]]; then
            print_color "RED" "Error: Number cannot be empty!"
        elif ! is_positive_integer "$base_num"; then
            print_color "RED" "Error: Please enter a valid non-negative integer!"
        else
            break
        fi
    done

    echo

    # Step 2: Full or Partial table?
    while true; do
        echo "Choose table type:"
        echo "1) Full table (1 to 10)"
        echo "2) Partial table (custom range)"
        read -p "Enter choice (1 or 2): " table_choice

        if [[ "$table_choice" == "1" ]]; then
            start=1
            end=10
            break
        elif [[ "$table_choice" == "2" ]]; then
            # Get start range
            while true; do
                read -p "Enter start of range (≥1): " start
                if ! is_positive_integer "$start" || [ "$start" -lt 1 ]; then
                    print_color "RED" "Error: Start must be a positive integer ≥1!"
                else
                    break
                fi
            done

            # Get end range
            while true; do
                read -p "Enter end of range (≥$start): " end
                if ! is_positive_integer "$end"; then
                    print_color "RED" "Error: End must be a positive integer!"
                elif [ "$end" -lt "$start" ]; then
                    print_color "RED" "Error: End must be ≥ start ($start)!"
                else
                    break
                fi
            done
            break
        else
            print_color "RED" "Invalid choice! Please enter 1 or 2."
        fi
    done

    echo

    # Step 3: Choose display style (Bonus Feature)
    while true; do
        echo "Choose display style:"
        echo "1) Classic (e.g., 5 x 3 = 15)"
        echo "2) Grid Table with Borders"
        echo "3) Compact (e.g., 5*3=15 5*4=20 ...)"
        read -p "Enter style (1, 2, or 3): " style_choice

        if [[ "$style_choice" =~ ^[1-3]$ ]]; then
            break
        else
            print_color "RED" "Invalid style! Choose 1, 2, or 3."
        fi
    done

    echo
    print_color "GREEN" "Generating $base_num × [$start to $end] table (Style $style_choice)..."
    echo

    # Display the table
    display_table "$base_num" "$start" "$end" "$style_choice"

    echo

    # Step 4: Ask to repeat (Bonus Feature)
    while true; do
        read -p "Generate another table? (y/n): " repeat
        case "${repeat,,}" in
            y|yes ) 
                echo
                continue 2  # Go back to outer loop
                ;;
            n|no )
                print_color "YELLOW" "Thank you for using Multiplication Table Generator!"
                exit 0
                ;;
            * )
                print_color "RED" "Please answer y or n."
                ;;
        esac
    done
done