function test_ok = ExecuteAnalysisRegressionTest(n_test, command)
%% Regression test for YANG VOCODER
%
% This test compares analysis reslut files with the reference files
% generated by the reference implementation
% This function is assumed to run the root of a Citc client
%
% test_ok = ExecuteAnalysisRegressionTest;
%
% test_ok = ExecuteAnalysisRegressionTest(n_test);
%
% test_ok = ExecuteAnalysisRegressionTest(n_test, command); % for debug.
%                                                  % Do not use
% Arguments
%   n_test : number of test files (integer upto 100 is valid input)
%
% Return value
%   test_ok : validation test resut. 1: validated, 0:failed validation

% Copyright 2016 Google Inc. All Rights Reserved
% Author: hidekik@google.com (Hideki Kawahara)

test_ok = false;
narginchk(0, 2)
if nargin == 0
  command = 'quick_test';
  n_test = 10;
elseif nargin == 1;
  command = 'test';
end;

%% make random selection from

if ~isOctave
  sprev = rng('shuffle');
  disp(sprev);
else
  % do nothing for octave
end;
base_directory = 'vctk_corpus/wav48/';
test_function_location = which('ExecuteAnalysisRegressionTest');
base_path_reference = [test_function_location(1:end - 31) 'analysisdata/'];

switch command
  case 'initialize' % This command should not be used
    disp('Do not proceed. Exit now!');
    keyboard
    dir_data = dir([base_directory 'p*']);
    n_speakers = length(dir_data);
    test_list = struct;
    for ii = 1:n_speakers
      path_name = [base_directory dir_data(ii).name];
      file_list = dir([path_name '/*.wav']);
      n_files = length(file_list);
      file_name = file_list(randi(n_files)).name;
      test_list(ii).fullpath = [path_name '/' file_name];
      test_list(ii).file_name = file_name;
    end;

    %% initialize test condition

    if ~isOctave
      random_seed = 12345;
      rng(random_seed); % initialize random number generator
    else
      oct_command1 = 'rand("seed", 1234)'; % for octave
      oct_command2 = 'randn("seed", 1234)'; % for octave
      eval(oct_command1);
      eval(oct_command2);
    end;
    system(['rm ' base_path_reference '*.bin']);
    n_test = n_speakers;

    % analysis test
    % Excitation information F0 and aperiodicity are extracted by
    % AnalyzeSpeechSource
    % Spectrum envelope is extracted by AnalyzeSpeechSpectra

    analysis_condition = GenerateOptionForSourceAnalysisNV;
    reference_bin_list = struct;
    base_name_reference = 'anly_';
    for ii = 1:n_test
      [x, fs] = AudioRead(test_list(ii).fullpath);
      disp([test_list(ii).file_name ' at:' datestr(now)]);
      source_information = AnalyzeSpeechSource(x, fs, analysis_condition);
      spectrum_information = ...
        AnalyzeSpeechSpectra(x, fs, source_information.f0, ...
                                     source_information.frame_time);
      reference_bin_list(ii) = ...
        SaveAnalysisResult(base_path_reference, base_name_reference, ...
        test_list(ii).file_name, source_information, spectrum_information);
    end;
    disp('generation completed');

    % regression generation
  case {'test', 'quick_test'}
    % Generate unique working directory name
    % This directory has to be deleted afterwards
    tmp_directory_name = ['/tmp/reg_test_' char(randi(25,1,10) + 97) ...
      datestr(now, 30) '/'];
    mkdir(tmp_directory_name);
    dir_data_reference = ...
      dir([base_path_reference '*_f0.bin']);
    n_files = length(dir_data_reference);
    [~, sorted_index] = sort(rand(n_files, 1));
    test_index_list = sorted_index(1:n_test);
    reference_bin_list = struct;

    %--- analysis for test
    analysis_condition = GenerateOptionForSourceAnalysisNV;
    test_bin_list = struct;
    base_name_test = 'anly_test_';
    for ii = 1:n_test
      if ~isOctave
        random_seed = 12345;
        rng(random_seed); % initialize random number generator
      else
        oct_command1 = 'rand("seed", 1234)'; % for octave
        oct_command2 = 'randn("seed", 1234)'; % for octave
        eval(oct_command1);
        eval(oct_command2);
      end;
      file_name = dir_data_reference(test_index_list(ii)).name;
      reference_bin_list(ii).name = file_name;
      wave_file_name = [file_name(6:13) '.wav'];
      audio_fullpath = [base_directory file_name(6:9) '/' wave_file_name];
      [x, fs] = AudioRead(audio_fullpath);
      disp([file_name ' at:' datestr(now)]);
      source_information = ...
        AnalyzeSpeechSource(x, fs, analysis_condition);
      spectrum_information = ...
        AnalyzeSpeechSpectra(x, fs, source_information.f0, ...
                                     source_information.frame_time);
      test_bin_list(ii).record = ...
        SaveAnalysisResult(tmp_directory_name, base_name_test, ...
                           wave_file_name, source_information, ...
                           spectrum_information);
    end;
    disp('second generation completed');
    %--- comparizon of reproducibility
    test_ok = true;
    acceptable_error = 1e-3;
    for ii = 1:n_test
      reference_name_root = reference_bin_list(ii).name(1:end-7);
      test_name_root = test_bin_list(ii).record.f0_name(1:end-7);
      if ~ValidateMaxRelativeValueDifference(base_path_reference, ...
                                             tmp_directory_name, ...
                                             reference_name_root, ...
                                             test_name_root, ...
                                             acceptable_error)
        disp([reference_bin_list(ii).name(1:end - 4) ' failed validation']);
        test_ok = false;
      end;
    end;
end;
if test_ok
  disp(['Analysis validation test passed with ' num2str(n_test) ' files.']);
end;
end
