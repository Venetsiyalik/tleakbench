%% Fig1_TLeakBench_Framework.m
% TLeakBench: benchmark construction, detection methods (B0-B4) and repair stage.
% Self-contained: run once -> Fig1_TLeakBench_Framework.png (600 dpi) + .pdf
clear; close all;
S = figStyle();
fig = newFig(7.16, 3.05);              % IEEE double column
ax = axes(fig,'Position',[0.005 0.01 0.99 0.98]); hold(ax,'on');
axis(ax,'equal'); axis(ax,[0 100 0 42]); axis(ax,'off');

cA = [0.93 0.95 0.98]; cB = [0.95 0.97 0.93]; cC = [0.99 0.95 0.91];
cK = [1 1 1];

% panel titles
text(ax,18,40.6,'(a) Benchmark construction','FontName',S.font,'FontSize',8,'FontWeight','bold','HorizontalAlignment','center');
text(ax,56,40.6,'(b) Leakage detection','FontName',S.font,'FontSize',8,'FontWeight','bold','HorizontalAlignment','center');
text(ax,88,40.6,'(c) Repair (RQ4)','FontName',S.font,'FontSize',8,'FontWeight','bold','HorizontalAlignment','center');
plot(ax,[36.6 36.6],[0.5 39.5],':','Color',S.light,'LineWidth',0.8);
plot(ax,[75.4 75.4],[0.5 39.5],':','Color',S.light,'LineWidth',0.8);

% ---- (a)
drawBox(ax,1,30,34,7.5,{'Pipeline spec sampler','8 leakage types \times variants, 3 models,','scalers, split/CV/tuning modes, 2 code styles'},cA,S);
drawBox(ax,1,19.5,34,7.5,{'Block-based code composer','one leaky statement per pipeline;','ground-truth line recorded'},cA,S);
drawBox(ax,1,9.5,10.5,7,{'160','leaky'},cK,S);
drawBox(ax,12.75,9.5,10.5,7,{'160 clean','twins'},cK,S);
drawBox(ax,24.5,9.5,10.5,7,{'40 hard','negatives'},cK,S);
drawBox(ax,1,0.8,34,6.2,{'Execution oracle on streamflow data','{\Delta}NSE = NSE_{leaky} - NSE_{twin}'},cA,S);
drawArrow(ax,18,30,18,27,S);
drawArrow(ax,6.25,19.5,6.25,16.5,S); drawArrow(ax,18,19.5,18,16.5,S); drawArrow(ax,29.75,19.5,29.75,16.5,S);
drawArrow(ax,6.25,9.5,10,7,S); drawArrow(ax,18,9.5,18,7,S);

% ---- (b)
drawBox(ax,38,30,36,7.5,{'TLeakBench item: Python pipeline','with numbered lines (240 items)'},cK,S);
drawBox(ax,38,15.5,11,10,{'B0-B2','prompt-only','LLM','(plain, taxonomy,','CoT)'},cB,S);
drawBox(ax,50.5,15.5,11,10,{'B3','static rules','(taxonomy-','derived)'},cB,S);
drawBox(ax,63,15.5,11,10,{'B4 hybrid','rule findings','\rightarrow LLM','verification'},cB,S);
drawBox(ax,38,1.5,36,8,{'Verdict (JSON): leakage, type L1-L8, line','Metrics: MCC, bal. acc., FPR (clean/hard),','type & line accuracy'},cK,S);
drawArrow(ax,43.5,30,43.5,25.5,S); drawArrow(ax,56,30,56,25.5,S); drawArrow(ax,68.5,30,68.5,25.5,S);
drawArrow(ax,61.5,20.5,63,20.5,S);
drawArrow(ax,43.5,15.5,43.5,9.5,S); drawArrow(ax,56,15.5,56,9.5,S); drawArrow(ax,68.5,15.5,68.5,9.5,S);
drawArrow(ax,35,13,38,32,S);

% ---- (c)
drawBox(ax,77,30,22,7.5,{'Leaky line + type','(oracle-localised)'},cC,S);
drawBox(ax,77,17.5,22,8,{'LLM patch','(code only)'},cC,S);
drawBox(ax,77,1.5,22,11,{'Executable checks:','syntax \rightarrow runs \rightarrow','rule clear \rightarrow','NSE \leq NSE_{twin} + 0.01'},cC,S);
drawArrow(ax,88,30,88,25.5,S); drawArrow(ax,88,17.5,88,12.5,S);
drawArrow(ax,74,5.5,77,5.5,S,'--');
text(ax,75.5,7.3,'end-to-end','FontName',S.font,'FontSize',6,'HorizontalAlignment','center','Rotation',0);

exportFig(fig,'Fig1_TLeakBench_Framework');

function drawBox(ax,x,y,w,h,txt,fc,S)
rectangle(ax,'Position',[x y w h],'Curvature',0.12,'FaceColor',fc, ...
    'EdgeColor',[0.35 0.35 0.35],'LineWidth',0.6);
text(ax,x+w/2,y+h/2,txt,'HorizontalAlignment','center','VerticalAlignment','middle', ...
    'FontName',S.font,'FontSize',6.5,'Interpreter','tex');
end

function drawArrow(ax,x1,y1,x2,y2,S,ls)
if nargin < 7, ls = '-'; end
c = [0.25 0.25 0.25];
d = [x2-x1, y2-y1]; L = norm(d); d = d/L; n = [-d(2) d(1)];
hl = 1.1; hw = 0.75;                       % head length / width (data units)
xe = x2 - hl*d(1); ye = y2 - hl*d(2);
plot(ax,[x1 xe],[y1 ye],'LineStyle',ls,'Color',c,'LineWidth',0.7);
patch(ax,[x2, xe+hw*n(1), xe-hw*n(1)],[y2, ye+hw*n(2), ye-hw*n(2)],c,'EdgeColor','none');
end

%% ===================== local functions =====================
function S = figStyle()
S.font = 'Times New Roman';
S.fs = 8;              % IEEE: 8 pt
S.c3B = [0.85 0.45 0.10];   % 3B  - orange
S.c7B = [0.12 0.36 0.65];   % 7B  - blue
S.cSt = [0.45 0.45 0.45];   % static rules - grey
S.light = [0.80 0.80 0.80];
end

function fig = newFig(wIn, hIn)
fig = figure('Units','inches','Position',[1 1 wIn hIn],'Color','w', ...
    'PaperUnits','inches','PaperSize',[wIn hIn],'PaperPosition',[0 0 wIn hIn]);
end

function styleAxes(ax, S)
set(ax,'FontName',S.font,'FontSize',S.fs,'LineWidth',0.6,'TickDir','out', ...
    'Box','off','XColor',[0.15 0.15 0.15],'YColor',[0.15 0.15 0.15]);
end

function exportFig(fig, name)
exportgraphics(fig,[name '.png'],'Resolution',600);
exportgraphics(fig,[name '.pdf'],'ContentType','vector');
fprintf('Saved: %s.png (600 dpi) and %s.pdf\n', name, name);
end
