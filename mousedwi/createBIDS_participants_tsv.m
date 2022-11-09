%% Template Matlab script to create an BIDS compatible participants.tsv file
% This example lists all required and optional fields.
% When adding additional metadata please use CamelCase
%
% DHermes, 2017
% updated by Zeru Peterson, 2021

%%
addpath(fullfile('/','home','zjpeters','matlabToolboxes','JSONio-main'));
clear;
root_dir = fullfile('/','media','zjpeters','Samsung_T5','mouseDevelopmental','threeGeneKO','rawdata');
% project_label = 'templates';

participants_tsv_name = fullfile(root_dir, 'participants.tsv');

%% make a participants table and save

t = readtable('./participants.xls');
% participant_id = {'sub-107' 'sub-108' 'sub-112' 'sub-113' 'sub-114' 'sub-115' 'sub-116' 'sub-117' 'sub-118' 'sub-193' 'sub-205' 'sub-207' 'sub-208' 'sub-209' 'sub-120' 'sub-192' 'sub-197' 'sub-198' 'sub-203'}';
% age = [43 43 42 42 42 42 43 43 43 47 47 47 47 47 44 47 47 47 47]';
% sex = {'f' 'f' 'm' 'm' 'f' 'f' 'm' 'm' 'm' 'm' 'f' 'f' 'f' 'f' 'f' 'm' 'm' 'm' 'f'}';
% genotype = {'mu' 'mu' 'wt' 'wt' 'mu' 'wt' 'mu' 'wt' 'mu' 'wt' 'wt' 'wt' 'wt' 'wt' 'mu' 'mu' 'wt' 'mu' 'wt'}';
% 
% t = table(participant_id, age, sex, genotype);

writetable(t, participants_tsv_name, 'FileType', 'text', 'Delimiter', '\t');

%% associated data dictionary

template = struct( ...
                  'LongName', '', ...
                  'Description', '', ...
                  'Levels', [], ...
                  'Units', '', ...
                  'TermURL', '');

dd_json.age = template;
dd_json.age.Description = 'age of the participant';
dd_json.age.Units = 'days';

dd_json.sex = template;
dd_json.sex.Description = 'sex of the participant as reported by the participant';
dd_json.sex.Levels = struct( ...
                            'm', 'male', ...
                            'f', 'female');

dd_json.genotype = template;
dd_json.genotype.Description = 'genotype of the subject';
dd_json.genotype.Levels = struct( ...
                                   'mu', 'Crispr 3 gene KO', ...
                                   'wt', 'wild-type');

%% Write JSON

json_options.indent = ' '; % this just makes the json file look prettier
% when opened in a text editor

jsonSaveDir = fileparts(participants_tsv_name);
if ~isdir(jsonSaveDir)
    fprintf('Warning: directory to save json file does not exist: %s \n', jsonSaveDir);
end

try
    jsonwrite(strrep(participants_tsv_name, '.tsv', '.json'), dd_json, json_options);
catch
    warning('%s\n%s\n%s\n%s', ...
            'Writing the JSON file seems to have failed.', ...
            'Make sure that the following library is in the matlab/octave path:', ...
            'https://github.com/gllmflndn/JSONio');
end
