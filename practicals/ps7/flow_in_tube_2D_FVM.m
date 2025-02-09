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
%  Code: Solution of 2D incompressible Navier-Stokes equations            %
%        using a staggered FVM, and time-explicit discretization.         %
%                                                                         %
% ----------------------------------------------------------------------- %

clc; close all; clear;

% Pre-Processing
L = 1.;             % Length of the domain [m]
nu = 1.e-2;         % Kinematic viscosity [m2/s]
tau = 20.;          % Total simulation time [s]
level = 7;          % [INOUT] Maximum level of refinement

% [INOUT] Grid setup
Lx = 8;
Ly = 1;
nx = 2^level;
hx = Lx/nx;
hy = hx;
ny = Ly/hy;
x = linspace (0., Lx, nx+1);
y = linspace (0., Ly, ny+1);
h = hx;

% [INOUT] Dirichlet boundary conditions everywhere
unwall = 0.;            % [INOUT] north side velocity [m/s]
uswall = 0.;
vewall = 0.;
vwwall = 0.;

% [INOUT] Inlet velocity
uin = 0.1;

% Poisson solver settings
maxiter = 10000;
beta = 1.9;
tolerance = 1.e-6;

% [INOUT] Time step setup
sigma = 0.5;
dt_diff = h^2/4/nu;
dt_conv = 4*nu/uin^2;       % [INOUT] uin instead of uwall
dt = sigma*min (dt_diff, dt_conv);
nsteps = tau/dt;
Re = uin*L/nu;              % [INOUT] uin instead of uwall

% Print initial info
fprintf ("Time step = %f - Re = %f\n", dt, Re);

% Memory allocations
u = zeros (nx+1, ny+2);
v = zeros (nx+2, ny+1);
p = zeros (nx+2, ny+2);

ut = zeros (nx+1, ny+2);
vt = zeros (nx+2, ny+1);

up = zeros (nx+1, ny+1);
vp = zeros (nx+1, ny+1);
pp = zeros (nx+1, ny+1);

% Coefficient for pressure equation
gamma = zeros (nx+2, ny+2);
gamma(:,:) = 1/4;
gamma(2,:) = 1/3;
gamma(:,2) = 1/3;
gamma(end-1,:) = 1/3;
gamma(:,end-1) = 1/3;
gamma(2,2) = 1/2;
gamma(2,end-1) = 1/2;
gamma(end-1,2) = 1/2;
gamma(end-1,end-1) = 1/2;

% [INOUT] Correction for gamma coefficient at inlet and outlet
gamma(2,:) = 1/3;       % Inlet section is treated like a boundary
gamma(nx+1,:) = 1/4;    % Outlet section is treated as an internal cell

% [INOUT] Correction of gamma coefficient for edges
gamma(2,2) = 1/2;
gamma(2,ny+1) = 1/2;
gamma(nx+1,2) = 1/3;
gamma(nx+1,ny+1) = 1/3;

% [INOUT] Initial condition
u(:,:) = uin;
ut = u;
vt = v;

% Time solution loop
time = 0.;
for m=1:nsteps
    time = time + dt;

    %-- Set boundary conditions

    u(:,1)   = 2*uswall - u(:,2);        % south wall
    u(:,end) = 2*unwall - u(:,end-1);    % north wall
    v(1,:)   = 2*vwwall - v(2,:);        % west wall
    v(end,:) = 2*vewall - v(end-1,:);    % east wall

    %-- [INOUT] set inlet conditions
    u(1,:) = uin;

    %-- [INOUT] set outlet conditions
    u(nx+1,:) = u(nx,:);
    v(nx+2,:) = v(nx+1,:);

    %-- Prediction: find temporary velocity

    for i=2:nx
        for j=2:ny+1
            ue = 0.5*(u(i+1,j) + u(i,j));
            uw = 0.5*(u(i,j) + u(i-1,j));
            un = 0.5*(u(i,j+1) + u(i,j));
            us = 0.5*(u(i,j) + u(i,j-1));
            vn = 0.5*(v(i+1,j) + v(i,j));
            vs = 0.5*(v(i+1,j-1) + v(i,j-1));

            Aij = (ue^2 - uw^2 + un*vn - us*vs)/h;
            Dij = (nu/h^2)*(u(i+1,j) + u(i-1,j) + u(i,j+1) + u(i,j-1) - 4.*u(i,j));

            ut(i,j) = u(i,j) + dt*(-Aij + Dij);
        end
    end

    for i=2:nx+1
        for j=2:ny
            vn = 0.5*(v(i,j+1) + v(i,j));
            vs = 0.5*(v(i,j) + v(i,j-1));
            ve = 0.5*(v(i+1,j) + v(i,j));
            vw = 0.5*(v(i,j) + v(i-1,j));
            ue = 0.5*(u(i,j+1) + u(i,j));
            uw = 0.5*(u(i-1,j+1) + u(i-1,j));

            Aij = (ve*ue - vw*uw + vn^2 - vs^2)/h;
            Dij = (nu/h^2)*(v(i+1,j) + v(i-1,j) + v(i,j+1) + v(i,j-1) - 4.*v(i,j));

            vt(i,j) = v(i,j) + dt*(-Aij + Dij);
        end
    end

    % [INOUT] Update boundary conditions for temporary velocity
    ut(1,:) = u(1,:);
    ut(nx+1,:) = u(nx+1,:);
    vt(nx+2,:) = v(nx+2,:);

    %-- Projection: find the pressure that statisfies the continuity

    for iter=1:maxiter

        % Update pressure using Jacobi/Gauss-Seidel/SOR
        for i=2:nx+1
            for j=2:ny+1
                delta = p(i+1,j) + p(i-1,j) + p(i,j+1) + p(i,j-1);
                S = h/dt*(ut(i,j) - ut(i-1,j) + vt(i,j) - vt(i,j-1));
                p(i,j) = beta*gamma(i,j)*(delta - S) + (1 - beta)*p(i,j);
            end
        end

        % Compute residuals
        res = 0.;
        for i=2:nx+1
            for j=2:ny+1
                delta = p(i+1,j) + p(i-1,j) + p(i,j+1) + p(i,j-1);
                S = h/dt*(ut(i,j) - ut(i-1,j) + vt(i,j) - vt(i,j-1));
                res = res + abs ( p(i,j) - gamma(i,j)*(delta - S) );
            end
        end
        res = res/(nx*ny);

        % Check residuals
        if (res <= tolerance)
            break;
        end

        % Check maxiter
        if (iter == maxiter-1)
            fprintf ("WARNING: Maximum number of iteration reached.\n");
        end
    end

    if (mod(m, 20) == 0)
        fprintf ("time = %f - Poisson iterations = %d\n", time, iter);
    end

    %-- Correction: update velocity according to the new pressure gradient

    for i=2:nx
        for j=2:ny+1
            u(i,j) = ut(i,j) - dt/h*(p(i+1,j) - p(i,j));
        end
    end

    for i=2:nx+1
        for j=2:ny
            v(i,j) = vt(i,j) - dt/h*(p(i,j+1) - p(i,j));
        end
    end

    % [INOUT]
    u(nx+1,:) = ut(nx+1,:) - dt/h*(p(nx+2,:) - p(nx+1,:));
end

%-- Linear interpolations
for i=1:nx+1
    for j=1:ny+1
        pp(i,j) = 0.25*(p(i,j) + p(i+1,j) + p(i,j+1) + p(i+1,j+1));
    end
end

for i=1:nx+1
    for j=1:ny+1
        up(i,j) = 0.5*(u(i,j+1) + u(i,j));
    end
end

for i=1:nx+1
    for j=1:ny+1
        vp(i,j) = 0.5*(v(i+1,j) + v(i,j));
    end
end

% [INOUT] Plot results in a 3x1 matrix
subplot (3,1,1);
surf (x, y, up');
view (2);
title('u.x');
axis tight;
colormap jet;
colorbar;
shading interp;

subplot (3,1,2);
surf (x, y, vp');
view (2);
title('u.y');
axis tight;
colormap jet;
colorbar;
shading interp;

subplot (3,1,3);
surf (x, y, pp');
view (2);
title('p');
axis tight;
colormap jet;
colorbar;
shading interp;

if (0)
    set(gcf, 'Color', 'w');

    x0=10;
    y0=10;
    width=1800;
    height=1200;
    set(gcf,'position',[x0,y0,width,height]);

    img = getframe(gcf);
    imwrite(img.cdata, 'tube.png');
end
