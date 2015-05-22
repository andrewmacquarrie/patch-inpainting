clear all;
close all;
clc;


%image = 'cow';
% image = 'bungee';
% image = 'man';

filen = 'rectilinCrew';
Aorg = imread(['.\WestminsterFrame\' filen '.png']);
Borg = imread(['.\WestminsterFrame\' 'equirectCrew' 'Target.png']);
Morg = imread(['.\WestminsterFrame\' filen '-mask.png']);

tic
A=patch_inpaint(Aorg,Borg,Morg);
toc

imshow(A)