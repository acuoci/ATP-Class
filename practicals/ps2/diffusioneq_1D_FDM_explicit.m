% ----------------------------------------------------------------------- %
%   __  __       _______ _               ____  _  _       _______ _____   %
%  |  \/  |   /\|__   __| |        /\   |  _ \| || |   /\|__   __|  __ \  %
%  | \  / |  /  \  | |  | |       /  \  | |_) | || |_ /  \  | |  | |__) | %
%  | |\/| | / /\ \ | |  | |      / /\ \ |  _ <|__   _/ /\ \ | |  |  ___/  %
%  | |  | |/ ____ \| |  | |____ / ____ \| |_) |  | |/ ____ \| |  | |      %
%  |_|  |_/_/    \_|_|  |______/_/    \_|____/   |_/_/    \_|_|  |_|      %
%                                                                         %
% ----------------------------------------------------------------------- %
%                                                                         %
%   Authors: Alberto Cuoci <alberto.cuoci@polimi.it>                      %
%            Edoardo Cipriano <edoardo.cipriano@polimi.it>                %
%   CRECK Modeling Group <http://creckmodeling.chem.polimi.it>            %
%   Department of Chemistry, Materials and Chemical Engineering           %
%   Politecnico di Milano                                                 %
%   P.zza Leonardo da Vinci 32, 20133 Milano                              %
%                                                                         %
% ----------------------------------------------------------------------- %
%                                                                         %
%   This file is part of Matlab4ATP framework.                            %
%                                                                         %
%   License                                                               %
%                                                                         %
%   Copyright(C) 2022 Alberto Cuoci                                       %
%   Matlab4ATP is free software: you can redistribute it and/or           %
%   modify it under the terms of the GNU General Public License as        %
%   published by the Free Software Foundation, either version 3 of the    %
%   License, or (at your option) any later version.                       %
%                                                                         %
%   Matlab4CFDofRF is distributed in the hope that it will be useful,     %
%   but WITHOUT ANY WARRANTY; without even the implied warranty of        %
%   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         %
%   GNU General Public License for more details.                          %
%                                                                         %
%   You should have received a copy of the GNU General Public License     %
%   along with Matlab4ATP. If not, see <http://www.gnu.org/licenses/>.    %
%                                                                         %
%-------------------------------------------------------------------------%
%                                                                         %
%  Code: 1D diffusion equation by the FD method using explicit            %
%        in time discretization method                                    %
%                                                                         %
% ----------------------------------------------------------------------- %

clc; close all; clear;

% ----------------------------------------------------------------------- %
% Pre-Processing
% ----------------------------------------------------------------------- %

% Data
alpha = 0.01;       % Diffusivity coefficient: alpha=k/rho/cp [m2/s]
L = 1;              % length of the domain [m]

% Build Mesh
npoints = 20;       % number of points that discretize the 1D domain
h = L/(npoints-1);  % distance between two consecutive points

% create a vector with the position of the points
% the vector is composed of "npoints" evenly spaced from x=0 to x=L
x = linspace(0,L,npoints);

% Time
tau = 50;                 % total simulation time (high enough to reach steady state) [s]
dt_diff = 0.5*h^2/alpha;  % Maximum time step that accounts for the diffusion phenomena (from Di=0.5)
sigma = 1.;                % Safety factor to avoid to work exactly at the minimum stability conditions
dt = sigma*dt_diff;       % Choice of the most limiting time step

% Print the computed minimum delta t. %g tells a "floating-point" number
% has to be printed. \n goes to the next line
fprintf("Maximum time step for diffusion  = %g\n", dt_diff);
fprintf("Selected time step               = %g\n", dt);

nsteps = tau/dt;    % Number of time steps to run

% Initial Conditions & Boundary Conditions
Tleft = 500;        % BC for temperature on the left side of the domain  [K]
Tright = 300;       % BC for temperature on the right side of the domain [K]
Tinit = 300;        % IC for temperature at time=0 [K].

% Memory allocations
T = ones(size(x))*Tinit;  % Create the temperature fields with dimension = number of points

% ----------------------------------------------------------------------- %
% Solution loop
% ----------------------------------------------------------------------- %

% Set Boundary conditions
T(1) = Tleft;         % Point 1 corresponds to the left boundary, where a BC is given
T(npoints) = Tright;  % The last point corresponds to the right boundary, where a BC is given

% loop over all the time-steps
for t=1:nsteps

    To = T;  % Store temperature at time t

    % Loop over all the internal points. The boundary points where already
    % solved setting the boundary conditions
    for i=2:npoints-1
        
        % Find temperature at time t+1 in every internal point.
        % - Explicit forward in time discretization of AD equation.
        % - 2nd order CDS scheme used for the diffusion terms
        T(i) = To(i) + dt*( alpha/h^2*(To(i+1)+To(i-1)-2*To(i)) );

        % if a source term is present: S = q[W/m3]/rho/cp; 
        % rho = 1; cp = 1; S = 10;
        % T(i) = To(i) + dt*( alpha/h^2*(To(i+1)+To(i-1)-2*To(i)) + S);
    end

    % On-The-Fly Post Processing
    if (mod(t,50)==1)   % => Every 50 time steps
        plot(x,T, "LineWidth", 1.8);      % Plot results
        grid on;                          % Show a grid
        xlabel("length [m]")              % Name of the x axis
        ylabel("Temperature [K]")         % Name of the y axis
        drawnow;                          % Show the plot
    end

end

