# Hypervolume Manager
This script manages the hypervolume indicator computation of multiple Pareto fronts in parallel, using the calculator by Fonseca et al., available at http://lopez-ibanez.eu/hypervolume


Dependencies
-----
*	<b>Bash</b>
*	<b><a href="http://lopez-ibanez.eu/hypervolume">Hypervolume Indicator Calculator</a></b>: The path of your executable must be supplied on the first line of this script.
*	<b><a href="https://www.gnu.org/software/parallel/">GNU Parallel</a></b>


Usage
-----
Run this script from within the folder of the ```.pof``` files that are to be processed, of which each contain a Pareto front.
A single file with the extension ```.ref``` must be present in the current directory, containing the appropriate hypervolume reference points for the many-objective problem.
For each ```.pof``` file found, a ```.hv``` file is written containing the calculated hypervolume.
A ```.ohv``` file is also written at the end of execution, containing the number of valid, convergent ```.pof``` files (i.e., the number of files that contain solutions that dominate the provided reference points), the mean hypervolume, and the standard deviation of hypervolume of the valid files.
All filenames may contain any character other than the null character, ```\0```.

Run with the following command:
```
<path to hv_manager.sh> [OPTIONS]
```

The available options allow for the modification of the number of concurrent calculations, whether to search for ```.pof``` files recursively, and the file \'stepping\'.
Use the option ```-h``` or ```--help``` to get a detailed description of the available options.
A sample of the required files and structure is provided in the ```examples``` folder.

For academic publications, be sure to also cite GNU Parallel as per ```parallel --citation```.