% I = PATCH_INPAINT(Iorg, Mask, verbose) inpaints an image
% 
%   Iorg  -  original image
%   Mask  -  replacement mask; pixels where mask==1 will be inpainted
%
%   I     - inpainted image
function A = patch_inpaint(Aorg, Borg, Morg, verbose, sigma) 

if nargin < 4
    verbose = true;
end
if nargin < 5
    sigma = 0.1;
end

if ~exist('CSH_nn.m','file')
    error('CSH_nn not found. Please download and add to path:  http://www.eng.tau.ac.il/~simonk/CSH/index.html');
end


LAB = @(I) applycform(I,makecform('srgb2lab'));
RGB = @(I) applycform(I,makecform('lab2srgb'));

Aorg = LAB(Aorg);
Borg = LAB(Borg);

width = 8;
csh_iterations = 5;
k = 1;
calcBnn = 0;

diffthresh = 10;

% Also accept RGB masks, but only use first channel
if size(Morg,3) > 1
    Morg = Morg(:,:,1);
end

% Determinte starting scale
[m n rgb] = size(Aorg);
startscale = -ceil(log2(min(m,n))) + 5;
scale = 2^(startscale);

% Resize image to starting scale
A = imresize(Aorg,scale);
B2 = imresize(Borg,scale);
M = imresize(Morg,scale);
M(M>0)=1;
M3 = repmat(M,[1 1 3])==1; % ME: mask replicated to all 3 channels

% Random starting guess for inpainted image
[m n rgb] = size(A);
Rnd = uint8(255*rand(m,n,rgb));
A(M3) = Rnd(M3);

% Go through all scales
for logscale = startscale:0

    scale = 2^(logscale);
    
    % Maximum number of iterations on this scale;
    % oscillations are possible
    iterations = 30;
    
    if verbose
        fprintf('Scale = 2^%d\n',logscale);
    end
    
    for iter = 1:iterations
        if verbose
            fprintf('  Iteration %2d/%2d',iter,iterations);
            imshow(RGB(A));
            pause(0.001)
        end
        
        % ME: create patch source image and remove masked section
        %B = A;
        %B(M3)=0;
        
        % Compute NN field
        [mb nb rgb] = size(B2);
        targetMask = zeros(mb, nb);
        
        CSH_ann = CSH_nn(A,B2,width,csh_iterations,k,calcBnn,targetMask);

        % Now be work in double precision
        A = double(A)./255;
        B2 = double(B2)./255;
        
        % Create new image by letting each patch vote
        R = zeros(size(A));
        Rcount = zeros(m,n);
        for i = 1:m
            for j = 1:n 
                if M(i,j) == 1
                    if 1<=i && i+width-1<=m && 1<=j && j+width-1<=n 
                        patch = A(i:i+width-1,j:j+width-1,:);
                        i2 = CSH_ann(i,j,2);
                        j2 = CSH_ann(i,j,1);
                        patch2 = B2(i2:i2+width-1,j2:j2+width-1,:);

                        d = sum( (patch(:)-patch2(:)).^2 );
                        sim = exp( -d / (2*sigma^2) );

                        pi = i:i+width-1;
                        pj = j:j+width-1;
                        R(pi,pj,:) = R(pi,pj,:) + sim*patch2;
                        Rcount(pi,pj) = Rcount(pi,pj) + sim;
                    end
                end
            end
        end

        % Normalize and 
        Rcount = repmat(Rcount,[1 1 3]);
        R(Rcount>0) = R(Rcount>0) ./ Rcount(Rcount>0);
        % Keep pixels outside mask
        R(~M3)=A(~M3);
        % Convert back to uint8
        Aprev = 255*A;
        A = uint8(255*R);
        
        B2 = uint8(255*B2); %ME: ?
        
        if iter>1
            % Measure how much image has changed
            diff = sum( (double(A(:))-double(Aprev(:))).^2 ) / sum(M(:)>0);
            if verbose
                fprintf(' diff = %f\n',diff);
            end
            % Stop iterating if change is low
            if diff < diffthresh 
                break;
            end
        elseif verbose
            fprintf('\n');
        end
    end
    
    %Upsample A for the next scale
    if logscale < 0
        Adata = imresize(Aorg,2*scale);
        [m n rgb] = size(Adata);
        A = imresize(A,[m n]);
        
        M = imresize(Morg,[m n]);
        M(M>0)=1;
        M3 = repmat(M,[1 1 3])==1;

        % Outside mask, A is equal to original image
        A(~M3) = Adata(~M3);
        
        % ME: above is complex because upsampling inside mask. But source
        % resize is just simple resize of original img B
        B2 = imresize(Borg,2*scale);
    end
end

A = RGB(A);
