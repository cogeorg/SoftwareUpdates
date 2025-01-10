#!/usr/bin/env bash
RUN_TYPE="$1"
STEP="$2"

BASEDIR=~/Dropbox/Papers/10_WorkInProgress/SoftwareUpdates/Data/
GITDIR=~/Git/SoftwareProductionNetworks/

# ###########################################################################
#
# TEST RUN 1.6.0 -- Pypi
#
# ###########################################################################
if [ "$RUN_TYPE" == "PYPITEST" ]; then
    echo "<< WORKING ON: NPM *TEST* USING STEP: $STEP"

    VERSION=1.6.0-2020-01-12
    BASENAME=Pypi-test
    LANGUAGE=Python
    DEPFILE=dependencies_$BASENAME.csv
    
    REPOIDENTIFIER=repo_dependencies_Pypi-test
    COVARIDENTIFIER=repo_covars_Pypi-test


    #
    # STEP 0 -- COPY ORIGINAL DATA
    #
    if [ "$STEP" == "0" ]; then
        mkdir $BASEDIR/$BASENAME/ 2>/dev/null
        cp ~/Downloads/$BASENAME/$REPOIDENTIFIER.* $BASEDIR/$BASENAME/
        cp ~/Downloads/$BASENAME/$COVARIDENTIFIER.csv $BASEDIR/$BASENAME/
    fi

    #
    # STEP 1 -- ANALYZE GRAPH
    #
    if [ "$STEP" == "1" ]; then
        ./80_analyze_graph.py $BASEDIR/$BASENAME/ $REPOIDENTIFIER True True False False 
        ./80_analyze_graph-VC.py $BASEDIR/$BASENAME/ $REPOIDENTIFIER
    fi

    #
    # STEP 2 -- COMPUTE  + ANALYZE EQUILIBRIA
    #
    if [ "$STEP" == "2" ]; then
        mkdir $BASEDIR/$BASENAME/$REPOIDENTIFIER/ 2>/dev/null
        ./90_compute_equilibrium.py $BASEDIR/$BASENAME/ $REPOIDENTIFIER $COVARIDENTIFIER 0.005 5 7
        ./91_calibrate_equilibrium.py $BASEDIR/$BASENAME/ $REPOIDENTIFIER 0.005 5 7
    fi

    #
    # STEP 3 -- COMPUTE FOR VARIOUS DELTA
    #
    SEQ_START=0.001
    SEQ_INC=0.001
    SEQ_END=0.05
    if [ "$STEP" == "3" ]; then
        rm $BASEDIR/$BASENAME/output_compute.log 2>/dev/null
        rm $BASEDIR/$BASENAME/e_output_compute.log 2>/dev/null
        for delta in `seq $SEQ_START $SEQ_INC $SEQ_END`
        do
            ./90_compute_equilibrium.py $BASEDIR/$BASENAME/ $REPOIDENTIFIER $COVARIDENTIFIER $delta 5 7 >> $BASEDIR/$BASENAME/output_compute.log 2>>$BASEDIR/$BASENAME/e_output_compute.log
        done

        rm $BASEDIR/$BASENAME/output_delta_calibration.csv 2>/dev/null
        rm $BASEDIR/$BASENAME/e_output_delta_calibration.csv 2>/dev/null
        for delta in `seq $SEQ_START $SEQ_INC $SEQ_END`
        do
            ./91_calibrate_equilibrium.py $BASEDIR/$BASENAME/$REPOIDENTIFIER/ equilibria_$delta-5 $delta 4 2 >> $BASEDIR/$BASENAME/output_delta_calibration.csv 2>>$BASEDIR/$BASENAME/e_output_delta_calibration.log
        done
    fi
fi


# ###########################################################################
#
# PRODUCTION RUN 1.6.0 -- NPM
#
# ###########################################################################
if [ "$RUN_TYPE" == "PRODUCTION" ]; then
    echo "<< WORKING ON: NPM *PRODUCTION* USING STEP: $STEP"

    VERSION=1.6.0-2020-01-12
    BASENAME=NPM-1.6.0Wyss
    LANGUAGE=JavaScript
    DEPFILE=dependencies_$BASENAME.csv

    REPOIDENTIFIER=repo_dependencies_NPM-matchedWyss+newIDs
    COVARIDENTIFIER=Wyss_npm_data6

    #
    # STEP 0 -- COPY ORIGINAL DATA
    #
    if [ "$STEP" == "0" ]; then
        mkdir $BASEDIR/$BASENAME/ 2>/dev/null
        cp -R ~/Downloads/NPM/Master/* $BASEDIR/$BASENAME/ 2>/dev/null
    fi

    #
    # OPTIONAL -- CREATE SMALLER SAMPLE FROM ORIGINAL DATA
    #
    if [ "$STEP" == "OPT1" ]; then
        ./33_sample_network.py $BASEDIR/$BASENAME/ dependencies_Cargo-repo2-matched-lcc.csv dependencies_Cargo-repo2-matched-lcc 0.01
    fi

    #
    # STEP 1 -- ANALYZE GRAPH
    #
    if [ "$STEP" == "1" ]; then
        ./80_analyze_graph.py $BASEDIR/$BASENAME/ $REPOIDENTIFIER True True False False 
        ./80_analyze_graph-VC.py $BASEDIR/$BASENAME/ $REPOIDENTIFIER
    fi

    #
    # STEP 2 -- COMPUTE EQUILIBRIA
    #
    if [ "$STEP" == "2" ]; then
        delta=0.004
        ./90_compute_equilibrium.py $BASEDIR/$BASENAME/ $REPOIDENTIFIER $COVARIDENTIFIER $delta 5 11
        ./91_calibrate_equilibrium.py $BASEDIR/$BASENAME/$REPOIDENTIFIER/ equilibria_$delta-5 $delta 4 2
    fi

    #
    # STEP 3 -- COMPUTE EQUILIBRIA FOR VARIOUS DELTA
    #
    SEQ_START=0.0001
    SEQ_INC=0.0002
    SEQ_END=0.006
    if [ "$STEP" == "3" ]; then
        date
        rm $BASEDIR/$BASENAME/output_compute.log 2>/dev/null
        rm $BASEDIR/$BASENAME/e_output_compute.log 2>/dev/null
        for delta in `seq $SEQ_START $SEQ_INC $SEQ_END`
        do
            echo $delta
            ./90_compute_equilibrium.py $BASEDIR/$BASENAME/ $REPOIDENTIFIER $COVARIDENTIFIER $delta 5 11 >> $BASEDIR/$BASENAME/output_compute.log 2>>$BASEDIR/$BASENAME/e_output_compute.log
        done
        date
    fi

    #
    # STEP 4 -- ANALYZE EQUILIBRIA FOR VARIOUS DELTA
    #
    if [ "$STEP" == "4" ]; then
        rm $BASEDIR/$BASENAME/output_delta_calibration.csv 2>/dev/null
        rm $BASEDIR/$BASENAME/e_output_delta_calibration.csv 2>/dev/null
        for delta in `seq $SEQ_START $SEQ_INC $SEQ_END`
        do
            ./91_calibrate_equilibrium.py $BASEDIR/$BASENAME/$REPOIDENTIFIER/ equilibria_$delta-5 $delta 4 2 >> $BASEDIR/$BASENAME/output_delta_calibration.csv 2>>$BASEDIR/$BASENAME/e_output_delta_calibration.log
        done
    fi
fi


# ###########################################################################
#
# TEST RUN 1.6.0 -- NPM
#
# ###########################################################################
if [ "$RUN_TYPE" == "TEST" ]; then
    echo "<< WORKING ON: NPM *TEST* USING STEP: $STEP"

    VERSION=1.6.0-2020-01-12
    BASENAME=NPM-test
    LANGUAGE=JavaScript
    DEPFILE=dependencies_$BASENAME.csv
    
    REPOIDENTIFIER=repo_dependencies_NPM-test-matchedWyss+newIDs
    COVARIDENTIFIER=Wyss_npm-test_data5


    #
    # STEP 0 -- COPY ORIGINAL DATA
    #
    if [ "$STEP" == "0" ]; then
        mkdir $BASEDIR/$BASENAME/ 2>/dev/null
        cp ~/Downloads/$BASENAME/$REPOIDENTIFIER.* $BASEDIR/$BASENAME/
        cp ~/Downloads/$BASENAME/$COVARIDENTIFIER.csv $BASEDIR/$BASENAME/
    fi

    #
    # STEP 1 -- ANALYZE GRAPH
    #
    if [ "$STEP" == "1" ]; then
        ./80_analyze_graph.py $BASEDIR/$BASENAME/ $REPOIDENTIFIER True True False False 
        ./80_analyze_graph-VC.py $BASEDIR/$BASENAME/ $REPOIDENTIFIER
    fi

    #
    # STEP 2 -- COMPUTE  + ANALYZE EQUILIBRIA
    #
    if [ "$STEP" == "2" ]; then
        mkdir $BASEDIR/$BASENAME/$REPOIDENTIFIER/ 2>/dev/null
        ./90_compute_equilibrium.py $BASEDIR/$BASENAME/ $REPOIDENTIFIER $COVARIDENTIFIER 0.005 5 7
        ./91_calibrate_equilibrium.py $BASEDIR/$BASENAME/ $REPOIDENTIFIER 0.005 5 7
    fi

    #
    # STEP 3 -- COMPUTE FOR VARIOUS DELTA
    #
    SEQ_START=0.001
    SEQ_INC=0.001
    SEQ_END=0.05
    if [ "$STEP" == "3" ]; then
        rm $BASEDIR/$BASENAME/output_compute.log 2>/dev/null
        rm $BASEDIR/$BASENAME/e_output_compute.log 2>/dev/null
        for delta in `seq $SEQ_START $SEQ_INC $SEQ_END`
        do
            ./90_compute_equilibrium.py $BASEDIR/$BASENAME/ $REPOIDENTIFIER $COVARIDENTIFIER $delta 5 7 >> $BASEDIR/$BASENAME/output_compute.log 2>>$BASEDIR/$BASENAME/e_output_compute.log
        done

        rm $BASEDIR/$BASENAME/output_delta_calibration.csv 2>/dev/null
        rm $BASEDIR/$BASENAME/e_output_delta_calibration.csv 2>/dev/null
        for delta in `seq $SEQ_START $SEQ_INC $SEQ_END`
        do
            ./91_calibrate_equilibrium.py $BASEDIR/$BASENAME/$REPOIDENTIFIER/ equilibria_$delta-5 $delta 4 2 >> $BASEDIR/$BASENAME/output_delta_calibration.csv 2>>$BASEDIR/$BASENAME/e_output_delta_calibration.log
        done
    fi
fi


# ###########################################################################
#
# PRODUCTION RUN 1.6.0 -- NPM
#
# ###########################################################################
if [ "$RUN_TYPE" == "PRODUCTION" ]; then
    echo "<< WORKING ON: NPM *PRODUCTION* USING STEP: $STEP"

    VERSION=1.6.0-2020-01-12
    BASENAME=NPM-1.6.0Wyss
    LANGUAGE=JavaScript
    DEPFILE=dependencies_$BASENAME.csv

    REPOIDENTIFIER=repo_dependencies_NPM-matchedWyss+newIDs
    COVARIDENTIFIER=Wyss_npm_data6

    #
    # STEP 0 -- COPY ORIGINAL DATA
    #
    if [ "$STEP" == "0" ]; then
        mkdir $BASEDIR/$BASENAME/ 2>/dev/null
        cp -R ~/Downloads/NPM/Master/* $BASEDIR/$BASENAME/ 2>/dev/null
    fi

    #
    # OPTIONAL -- CREATE SMALLER SAMPLE FROM ORIGINAL DATA
    #
    if [ "$STEP" == "OPT1" ]; then
        ./33_sample_network.py $BASEDIR/$BASENAME/ dependencies_Cargo-repo2-matched-lcc.csv dependencies_Cargo-repo2-matched-lcc 0.01
    fi

    #
    # STEP 1 -- ANALYZE GRAPH
    #
    if [ "$STEP" == "1" ]; then
        ./80_analyze_graph.py $BASEDIR/$BASENAME/ $REPOIDENTIFIER True True False False 
        ./80_analyze_graph-VC.py $BASEDIR/$BASENAME/ $REPOIDENTIFIER
    fi

    #
    # STEP 2 -- COMPUTE EQUILIBRIA
    #
    if [ "$STEP" == "2" ]; then
        delta=0.004
        ./90_compute_equilibrium.py $BASEDIR/$BASENAME/ $REPOIDENTIFIER $COVARIDENTIFIER $delta 5 11
        ./91_calibrate_equilibrium.py $BASEDIR/$BASENAME/$REPOIDENTIFIER/ equilibria_$delta-5 $delta 4 2
    fi

    #
    # STEP 3 -- COMPUTE EQUILIBRIA FOR VARIOUS DELTA
    #
    SEQ_START=0.0001
    SEQ_INC=0.0002
    SEQ_END=0.006
    if [ "$STEP" == "3" ]; then
        date
        rm $BASEDIR/$BASENAME/output_compute.log 2>/dev/null
        rm $BASEDIR/$BASENAME/e_output_compute.log 2>/dev/null
        for delta in `seq $SEQ_START $SEQ_INC $SEQ_END`
        do
            echo $delta
            ./90_compute_equilibrium.py $BASEDIR/$BASENAME/ $REPOIDENTIFIER $COVARIDENTIFIER $delta 5 11 >> $BASEDIR/$BASENAME/output_compute.log 2>>$BASEDIR/$BASENAME/e_output_compute.log
        done
        date
    fi

    #
    # STEP 4 -- ANALYZE EQUILIBRIA FOR VARIOUS DELTA
    #
    if [ "$STEP" == "4" ]; then
        rm $BASEDIR/$BASENAME/output_delta_calibration.csv 2>/dev/null
        rm $BASEDIR/$BASENAME/e_output_delta_calibration.csv 2>/dev/null
        for delta in `seq $SEQ_START $SEQ_INC $SEQ_END`
        do
            ./91_calibrate_equilibrium.py $BASEDIR/$BASENAME/$REPOIDENTIFIER/ equilibria_$delta-5 $delta 4 2 >> $BASEDIR/$BASENAME/output_delta_calibration.csv 2>>$BASEDIR/$BASENAME/e_output_delta_calibration.log
        done
    fi
fi

# ###########################################################################
#
# PRODUCTION RUN 1.6.0 -- Cargo
#
# ###########################################################################
VERSION=1.6.0-2020-01-12
BASENAME=Cargo-1.6.0
LANGUAGE=Rust
DEPFILE=dependencies_$BASENAME.csv

#
# STEP 0 -- COPY ORIGINAL DATA
#
# mkdir $BASEDIR/$BASENAME/ 2>/dev/null
# cp -R ~/Dropbox/Papers/10_WorkInProgress/SoftwareNetworks/Data/Cargo/Master/* $BASEDIR/$BASENAME/ 2>/dev/null

#
# OPTIONAL -- CREATE SMALLER SAMPLE FROM ORIGINAL DATA
#
# ./33_sample_network.py $BASEDIR/$BASENAME/ dependencies_Cargo-repo2-matched-lcc.csv dependencies_Cargo-repo2-matched-lcc 0.01

#
# STEP 1 -- COMPUTE EQUILIBRIA
#
# ./90_compute_equilibrium.py $BASEDIR/$BASENAME/ test2 test2 0.1 4
# ./90_compute_equilibrium.py $BASEDIR/$BASENAME/ dependencies_Cargo-repo2-matched-lcc-cut2 20_master_Cargo-matched-cut2 0.1 5

# for theta in 0.0001 0.001 0.005 0.01 0.05 0.1 0.15 0.2 
# do
#     ./90_compute_equilibrium.py $BASEDIR/$BASENAME/ dependencies_Cargo-repo2-matched-lcc-cut2 20_master_Cargo-matched-cut2 $theta 5
# done

#
# OPTIONAL -- CREATE SAMPLE NETWORKS AND ANALYZE THEM TO UNDERSTAND MODEL
#

# for i in 32 64 128 256 512 1024
#     do ./34_create_sample_networks.py $BASEDIR/$BASENAME/test/ test $i 0.0 0.0
# done

# NETWORKS: star_in star_out complete 
# for NETID in star_in star_out complete 
#     do for DISTID in log_normal equal 
#         do for i in 32 64 128 256 512 1024
#             do ./90_compute_equilibrium.py $BASEDIR/$BASENAME/test/ test-$NETID-$i test_theta-$DISTID-$i 0.05 1 ; cd $BASEDIR/$BASENAME/test/ ; cat summary_test-$NETID*.csv > summary_test-$NETID-$DISTID.csv ; mv summary_test-$NETID-$DISTID.csv ../ ; cd -
#         done
#     done
# done


# ###########################################################################
#
# PRODUCTION RUN 1.6.0 -- Pypi
#
# ###########################################################################
VERSION=1.6.0-2020-01-12
BASENAME=Pypi-1.6.0
LANGUAGE=Rust
DEPFILE=dependencies_$BASENAME.csv

#
# STEP 0 -- COPY ORIGINAL DATA
#
# mkdir $BASEDIR/$BASENAME/ 2>/dev/null
# cp -R ~/Dropbox/Papers/10_WorkInProgress/SoftwareNetworks/Data/Pypi/Master/* $BASEDIR/$BASENAME/ 2>/dev/null

#
# OPTIONAL -- CREATE SMALLER SAMPLE FROM ORIGINAL DATA
#
# ./33_sample_network.py $BASEDIR/$BASENAME/ dependencies_Pypi-repo2-matched-lcc.csv dependencies_Pypi-repo2-matched-lcc 0.01

#
# STEP 1 -- COMPUTE EQUILIBRIA
#
# ./90_compute_equilibrium.py $BASEDIR/$BASENAME/Master/ test2 test2 0.1 4
# ./90_compute_equilibrium.py $BASEDIR/$BASENAME/ dependencies_Pypi-repo2-matched-lcc 20_master_Pypi-matched 0.1 5
