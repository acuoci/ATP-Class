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
%  Code: Solution of Advection-Diffusion-Reaction equations in 1D using   %
%        FVM discretization. The reaction terms are treated using the     %
%        Operator-Splitting approach and solved in a coupled manner       %
%        using ode45. They refer to the reactions: A->B->C                %
%                                                                         %
%        RA = -k1*CA^2;                                                   %
%        RB =  k1*CA^2 - k2*CB;                                           %
%        RC =  k2*CB;                                                     %
%                                                                         %
%-------------------------------------------------------------------------%

clc; clear; close all;

%-------------------------------------------------------------------------%
% Problem Data
%-------------------------------------------------------------------------%

global k1 k2;

L = 2;
tau = 10;
ncells = 100;
u = 1;
Dmix = 1.e-2;
k1 = 10;
k2 = 1;

CAin = 1.;
CBin = 0.;
CCin = 0.;

nsteps = 1000;

%-------------------------------------------------------------------------%
% Pre-Processing
%-------------------------------------------------------------------------%

% Build Mesh
h = L/ncells;
x = linspace(0, L, ncells+1);

% Choose dt for stability
dt = tau/nsteps;

%-------------------------------------------------------------------------%
% Memory Allocations
%-------------------------------------------------------------------------%

CA = zeros(1, ncells+2);
CB = zeros(1, ncells+2);
CC = zeros(1, ncells+2);

RA = zeros(1, ncells+2);
RB = zeros(1, ncells+2);
RC = zeros(1, ncells+2);

CAo = CA; CBo = CB; CCo = CC;

%-------------------------------------------------------------------------%
% Solution loop
%-------------------------------------------------------------------------%

t = 0.;
for is=1:nsteps

    %---------------------------------------------------------------------%
    % Set the Boundary Conditions
    %---------------------------------------------------------------------%
    
    % Inlet Section
    CA(1) = 2*CAin - CA(2);
    CB(1) = 2*CBin - CB(2);
    CC(1) = 2*CCin - CC(2);

    % Outlet Section
    CA(ncells+2) = CA(ncells+1);
    CB(ncells+2) = CB(ncells+1);
    CC(ncells+2) = CC(ncells+1);

    %---------------------------------------------------------------------%
    % Solve Advection-Diffusion Equations (No Reactions)
    %---------------------------------------------------------------------%

    CA = AdvectionDiffusionReaction1D (CA, RA, u, Dmix, dt, h, ncells);
    CB = AdvectionDiffusionReaction1D (CB, RB, u, Dmix, dt, h, ncells);
    CC = AdvectionDiffusionReaction1D (CC, RC, u, Dmix, dt, h, ncells);

    %---------------------------------------------------------------------%
    % Solve just the reactive step in a coupled manner
    %---------------------------------------------------------------------%

    for i=2:ncells+1
        [t,y] = ode45 (@odefun, [0 dt], [CA(i), CB(i), CC(i)]);
        CA(i) = y(end,1);
        CB(i) = y(end,2);
        CC(i) = y(end,3);
    end

    %---------------------------------------------------------------------%
    % Post-Processing
    %---------------------------------------------------------------------%
    
    CAp = CellToFaceInterpolation (CA, ncells);
    CBp = CellToFaceInterpolation (CB, ncells);
    CCp = CellToFaceInterpolation (CC, ncells);

    if (mod(is,20)==1)
        fprintf ("Iter: %d - Time: %f\n", is, t);
        hold off;
        plot (x, CAp, "LineWidth", 1.8); hold on;
        plot (x, CBp, "LineWidth", 1.8);
        plot (x, CCp, "LineWidth", 1.8);
        xlabel ("lenght [m]"); ylabel ("Concentration [kmol/m3]");
        % legend ("CA", "CB", "CC");
        xlim([0 L]); ylim([0 1]);
        drawnow;
    end

    % Advance the simulation time
    t = t + dt;
end

%-------------------------------------------------------------------------%
% Useful functions
%-------------------------------------------------------------------------%

function dCidt = odefun (t, y)

    global k1 k2;

    CA = y(1); CB = y(2); CC = y(3);

    dCidt(1) = -k1*CA^2;
    dCidt(2) =  k1*CA^2 - k2*CB;
    dCidt(3) =  k2*CB;

    dCidt = dCidt';
end

function C = AdvectionDiffusionReaction1D (C, S, u, Dmix, dt, h, ncells)

    Co = C;
    for i=2:ncells+1
        Ai = u*h/2*(Co(i+1) - Co(i-1));
        Di = Dmix*(Co(i+1) + Co(i-1) - 2*Co(i));
        Ri = S(i);

        C(i) = Co(i) + dt/h^2*(-Ai + Di + Ri);
    end

end

function Cface = CellToFaceInterpolation (Ccell, ncells)

    Cface = zeros(1,ncells+1);
    for i=1:ncells+1
        Cface(i) = 0.5*(Ccell(i+1) + Ccell(i));
    end

end