clear all;
close all;
clc;


image = 'cow';
% image = 'bungee';
% image = 'man';

Aorg = imread([image '.png']);

Borg = imread('bungee.png');

Morg = imread([image '-mask.png']);

tic
A=patch_inpaint(Aorg,Borg,Morg);
toc

imshow(A)