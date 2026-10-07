function P = local_paths()
% Machine-specific paths. Edit the three lines below; no other file in the
% repository contains a path.
%
%   P = local_paths();     % also puts the repository and EEGLAB on the path

P.eeglab   = 'C:\path\to\eeglab2022.1';
P.Gwon2023 = 'D:\data\Gwon_2023\edf';     % folder holding ME*.edf
P.Gwon2024 = 'D:\data\Gwon_2024';         % folder holding ME*.bdf

root      = fileparts(mfilename('fullpath'));
P.results = fullfile(root, 'results');
if ~isfolder(P.results), mkdir(P.results); end

addpath(root, fullfile(root,'core'), fullfile(root,'qc'), fullfile(root,'analysis'));

if isempty(which('pop_biosig'))            % EEGLAB not started yet
    assert(isfolder(P.eeglab), 'EEGLAB folder not found: %s (edit local_paths.m)', P.eeglab);
    addpath(P.eeglab);
    eeglab nogui
end
end
