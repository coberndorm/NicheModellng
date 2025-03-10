function classifiers=FrontierDepthAveragedPreprocessing(T,layerInfo,alpha,percentile,show,outlier,outlier2, expCorrelation)
% classifiers=FrontierDepthAveragedPreprocessing(in,show,outlier,outlier2,alpha)
% 
% DESCRIPTION 
%   'FrontierDepthAveragedPreprocessing' takes species presence-data(observations) over 
%   a map and generates a niche probability intensity map, by using the
%   radius 
%
% REQUIRED INPUTS
%   T: Table given by sampleVS with species samples and information
%   ReadInfo: an strcuture generated by 'ReadLayers' function
%   
% OPTIONAL INPUTS
%   alpha: shrinking factor for the boundary, alpha=[0,1]
%   percentile: percentile until which the radius results will be averaged
%   show: if the boundary and the estimated map will show
%   outlier1: If the outliers are removed before normalization
%   outlier2: a integer with the number of required samples 
% 
% OUTPUTS:
%   classifiers.nodes: An array containing the boundary points with ther
%                       environmental covariates
%   classifiers.index: Indexes in T of the boundary points
%   classifiers.radius: radius of every point to its closest boundary point
%   classifiers.normalizers: normalization coefficients for environmental
%                            covariates
%   classifiers.T: Array of every sample data with their environmental
%                   covariate
%   classifiers.map: Array containing the probability  intensity of species
%                    presence in every map pixel
%%  
if nargin <3
    alpha = 0;
end
if nargin <4
    percentile = 0;
end
if nargin <5
    show = false;    
end
if nargin <6
    outlier=false;
end
if nargin <7
    outlier2=false;
end
if nargin <8
    expCorrelation = 0.9;
end
%out1 and ouT will be the samples taken out by the outlier detection
out1 = [];
ouT = [];

%Preprocessing the sample data
niche = nicheData(T,3,4:22);
niche = niche.aClus(expCorrelation);
niche = niche.regressor(false);
niche = niche.setProcFun();
points = niche.procFun(T{:,niche.inds});

%Preprocessing the map environmental data
Z = layerInfo.Z; % Enviromental Info in each point of the map
[bio,pointer] = niche.map2vec(layerInfo.Z);
data = niche.procFun(bio);

%preparing initial important data
reps = size(Z); % Size of Z
R = layerInfo.R; % Geographic cells Reference
template = Z(:, :, 1); % Array of map size

% Determine which pixels of the array are not part of the map
idx = find(pointer==1);

% Outlier detection before PCA
if outlier
    [~,~,RD,chi_crt] = DetectMultVarOutliers(points(:,:));
    id_out = RD>chi_crt(4);
    out1 = points(id_out,:);
    points = points(~id_out,:);
end

%PCA proyection of points
[coeff,~,~,~,explained]=pca(points(:,:));
pin=points(:,:)*coeff(:,1:3);

if ~isempty(out1)
    out1=out1*coeff(:,1:3);
end

%outlier detection pos-PCA
if outlier2
    %siz=round(size(pin,1)*0.3);
    [~,~,RD,chi_crt]=DetectMultVarOutliers(pin);
    id_out=RD>chi_crt(4);
    ouT=pin(id_out,:);
    pin=pin(~id_out,:);
end

%generating the boundary
nodes = boundary(pin(:,1),pin(:,2),pin(:,3),alpha);

boundPointsIndex = unique(nodes)';
boundPoints = points(boundPointsIndex,:);
pointsSize = length(boundPointsIndex);
samples = length(points);
radius = zeros(pointsSize,samples);
map = ones(reps(1), reps(2));

for j=1:samples
    for i=1:pointsSize
        radius(i,j)=norm(points(boundPointsIndex(i),:)-points(j,:));
        if radius(i,j) == 0
            radius(:,j) = 0;
            continue
        end
    end
end
radiusClass = zeros(percentile,samples);

for i=1:percentile
    radiusClass(i,:) = prctile(radius,i);
end

radiusIndex = find(radiusClass>0);
radiusClass = radiusClass(:,setdiff(1:end,boundPointsIndex));

response = NaN(1,length(radiusClass));
intensity = NaN(1,length(idx));

for i=1:length(idx)
    for j=1:length(radiusClass)
        response(j) = norm(points(radiusIndex(j),:)-data(i,:));
    end
    probability = 0;
    for k=1:percentile
        probability = probability + sum(response<=radiusClass(k));
    end
    intensity(i) = probability/percentile;
end

intensity = (intensity - min(intensity))./(max(intensity)-min(intensity));

final = NaN(length(template(:)),1);

final(idx)=intensity;

map(:) = final(:);

classifiers.nodes = boundPoints;
classifiers.index = radiusIndex;
classifiers.radius = radiusClass;
classifiers.T = T;
classifiers.map = map;

outT=[out1;ouT];

if show
    trisurf(nodes,pin(:,1),pin(:,2),pin(:,3), 'Facecolor','cyan','FaceAlpha',0.8); axis equal;
    hold on
    plot3(pin(:,1),pin(:,2),pin(:,3),'.r')
    hold off
    

    figure
    clf
    geoshow(map, R, 'DisplayType','surface');
    contourcmap('jet',0:0.05:1, 'colorbar', 'on', 'location', 'vertical')
end