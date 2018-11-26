#!/bin/bash
#
# Author: Mykel Shumay.
# License LGPLv3: GNU LGPL version 3
#
# This script runs the hypervolume calculator by Fonseca et al. in parallel for multiple .pof files.
# Writes a .hv file containing the hypervolume for each .pof file found.
# Also writes a .ohv file containing the number of files,
# 	the mean hypervolume, and the standard deviation of hypervolume.
#
# Run this script from within the folder of the .pof files that you want to use.
# Pass arguments of "-j N" or "--jobs N" to set the max number of parallel processes.
# 	Defaults to the number of available cores.
# Pass arguments of "-s N" or "--stepping N" to set how many .pof files are stepped over/skipped per calculation of each run,
# 	if there are multiple generations per run.
# Pass arguments of "-r" or "--recursive" to search for .pof files recursively.
# Pass arguments of "-h" or "--help" to be provided with a fuller explanation of this script.
#
# Calculates using all found .pof files.
# Reads a single .ref file in the current folder for the hypervolume reference point.
# All .pof files provided must be of the same problem type, and so must use the same reference point.
# Handles all whitespace (newlines included) and wildcard characters in filenames.

# Enter the path to your hv executable.
hv_exec_path="/home/m/repos/hv-2.0rc2-src/hv"

version="1.0"
num_parallel_jobs=""
stepping=1
IFS=' ' max_depth=($(echo "-maxdepth 1"))
while (( "$#" )); do
	case "$1" in
		-j|--jobs)
			case "$2" in
				[0]*|''|*[!0-9]*)
					printf "Invalid jobs value, max number of parallel jobs set to number of cores.\n";;
				*)
					num_parallel_jobs=$2
					printf "Setting max number of parallel jobs to %d.\n" $num_parallel_jobs
			esac
			shift 2
			;;

		-s|--stepping)
			case "$2" in
				[0]*|''|*[!0-9]*)
					printf "Invalid stepping value, set to 1.\n";;
				*)
					stepping=$2
					printf "Setting stepping to %d.\n" $stepping
			esac
			shift 2
			;;

		-r|--recursive)
			max_depth=("")
			printf "Searching for .pof files recursively.\n"
			shift
			;;

		-v|--version)
			printf "hv_manager version $version\n"
			printf "License LGPLv3: GNU LGPL version 3 <https://www.gnu.org/licenses/lgpl>.\n"
			printf "Written by Mykel Shumay.\n"
			printf "\n\n"
			exit 0
			;;

		-h|--help)
			printf "This program manages the hypervolume calculations in parallel of many Pareto fronts using the hypervolume calculator by Fonseca et al., available at <http://lopez-ibanez.eu/hypervolume>.\n"
			printf "Run this program from within the directory of the Pareto front files you want to process, with extension '.pof'.\n"
			printf "The path to your hypervolume executable must be provided on the first line of this script.\n"
			printf "A single file containing the hypervolume reference point must be present in the current directory, with extension '.ref'.\n"
			printf "For each processed '.pof' file, a '.hv' file will be written containing the calculated hypervolume.\n"
			printf "Also writes a '.ohv' file in the current directory containing the number of valid files (i.e., number of convergent fronts), the mean hypervolume, and the standard deviation of hypervolume of the valid files.\n"
			printf "View the 'examples' folder in the repository for a sample of the required files and structure.\n"
			printf "Requires GNU Parallel be installed, available at <https://www.gnu.org/software/parallel>\n"

			printf "\nOptions:\n"
			printf " -j N, --jobs N        maximum number of parallel jobs\n"
			printf " -s N, --stepping N    if a filename contains a generation number in the form '_genX', only process it if X is divisible by N\n"
			printf " -r, --recursive       find '.pof' files recursively\n"
			printf " -h, --help            display this help page and exit\n"
			printf " -v, --version         output version information and exit\n"
			printf "\n\n"
			exit 0
			;;

		*)
			printf "Option not recognized: '$1'\n\n"
			shift
			;;
	esac
done

if (( ${#hv_exec_path} == 0 )); then
	printf "\nError: Hypervolume executable path not provided, please edit the script's first line to include it.\n"
	printf "If you do not have an executable, please visit <http://lopez-ibanez.eu/hypervolume>.\n\n"
	exit 1
fi
export hv_exec_path

if ! [ -x "$(command -v parallel)" ]; then
	printf "\nError: GNU Parallel is either not installed or is not listed on your PATH.\n"
	printf "Please visit <https://www.gnu.org/software/parallel> for more information.\n\n"
	exit 1
fi

if [ -z "$num_parallel_jobs" ]; then
	num_parallel_jobs=$(parallel --number-of-cores)
fi

calcHV() {
	# Writes to .hv file in normal form, returns hypervolume in decimal format
	# $1: ./filename.pof
	# $2: Number of file

	# Calculates hypervolume
	IFS=
	hv_val=$(cat $1 | ${hv_exec_path} -r "${ref_points}")
	
	# Converts from normal form, if necessary
	IFS=' '
	hv_val=$(printf "%.30f" $hv_val)

	# Prints result in normal form to .hv file
	IFS=
	printf "%.10e" $hv_val > ${1:0:-4}.hv
	# Prints result in decimal format to stdout, effectively returning the value
	printf "%.20f " $hv_val

	# Prints to stderr when finished.
	# Note that subshell output is governed by the order of jobs for data integrity purposes,
	# so that if jobs #1 & #2 finish before job #0, there will be no stdout/stderr output until job #0 also finishes.
	# Writing to files, however, is completed regardless of this.
	>&2 printf "Finished hv calculation of file #$2: $1\nHypervolume: %.10e\n\n" $hv_val

}
export -f calcHV

#                     #
# Input Section Start #
#                     #
IFS=

echo "Searching for .ref file."
while read -r -d $'\0' f; do
	ref_points_files+=("$f")
done < <(find . -maxdepth 1 -type f -iname "*.ref" -printf '%p\0')

if (( ${#ref_points_files[@]} == 0 )); then
	echo "Error: No .ref file found. Exiting."
	exit 1
elif (( ${#ref_points_files[@]} != 1 )); then
	echo "Error: Multiple .ref files found. Exiting."
	exit 1
else
	ref_points=$(printf "%s " $(cat ${ref_points_files[0]}))
	export ref_points=${ref_points:0:-1}
	echo "Found .ref file: ${ref_points_files[0]:2}"
fi

printf "\nSearching for .pof files.\n"
# Sorts files by modification timestamps in reverse order (oldest first)
while read -r -d $'\0' f; do
	# If there is a generation number, narrow down the value and compare to the stepping
	regex="_gen{1}[0-9]+"
	if [[ "$f" =~ $regex ]]; then
		file_gen_num=${BASH_REMATCH[0]:4}
		# Convert to base10 to unpad the generation number
		file_gen_num=$((10#$file_gen_num))
		# If the generation number is divisible by the stepping, add it to the files to process
		if (( $file_gen_num % $stepping == 0 )); then
			files+=("$f")
		fi
	else
		files+=("$f")
	fi
done < <(find . ${max_depth[@]} -type f -iname "*.pof" -printf '%T@\t%p\0' | sort -z | cut -z -f 2-)

num_files=${#files[@]}
if (( $num_files == 0 )); then
	echo "Error: No .pof files found. Exiting."
	exit 1
fi
printf "Found %d .pof files.\n" $num_files
#                   #
# Input Section End #
#                   #

if (( $num_files < $num_parallel_jobs )); then
	num_parallel_jobs=$num_files
fi

# Braces force immediate parsing of the rest of the script file
{
	IFS=$'\n'
	# Computes all hypervolumes in parallel
	printf "\nCalculating all hypervolumes across %d processes.\n\n" $num_parallel_jobs
	IFS=' ' read -a results <<< $(parallel --null --keep-order --jobs $num_parallel_jobs calcHV ::: "${files[@]}" :::+ $(seq 0 1 $(( num_files-1 ))))

	# Determines validity of each result
	num_valid_files=0
	hv_sum=0.0
	for result in ${results[@]}; do
		if (( $(bc -l <<< "$result != 0.0") )); then
			hv_sum=$(bc -l <<< "$hv_sum + $result")
			num_valid_files=$(( $num_valid_files + 1 ))
			valid_results+=($result)
		fi
	done
	if (( $num_valid_files == 0 )); then
		echo "Error: No valid .pof files. Exiting."
		exit 1
	fi
	printf "Number of valid files: %d\n" $num_valid_files

	# Calculates mean of resulting hypervolumes
	hv_mean=$(bc -l <<< "$hv_sum / $num_valid_files")
	printf "Mean Hypervolume:\t%.10e\n" $hv_mean

	# Calculates standard deviation of resulting hypervolumes
	variance_sum=0.0
	for index in ${!valid_results[@]}; do
		val=${valid_results[$index]}
		variance_sum=$(bc -l <<< "$variance_sum + ($val - $hv_mean) * ($val - $hv_mean)")
	done
	hv_std_dev=$(bc -l <<< "sqrt($variance_sum / $num_valid_files)")
	printf "Standard Deviation:\t%.6e\n" $hv_std_dev

	# Writes .ohv file in current working directory
	printf "Number of valid files: %d\nMean: %.10e\nStandard Deviation: %.10e" $num_valid_files $hv_mean $hv_std_dev > "overall_hypervolume.ohv"
	exit 0
}