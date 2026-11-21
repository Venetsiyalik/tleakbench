%% Fig2_Oracle_Inflation.m
% Score inflation caused by each leakage type (execution oracle, 160 minimal pairs).
% Self-contained: run once -> Fig2_Oracle_Inflation.png (600 dpi) + .pdf
clear; close all;
S = figStyle();
grp   = [1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 5 5 5 5 5 5 5 5 5 5 5 5 5 5 5 5 5 5 5 5 6 6 6 6 6 6 6 6 6 6 6 6 6 6 6 6 6 6 6 6 7 7 7 7 7 7 7 7 7 7 7 7 7 7 7 7 7 7 7 7 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8];
delta = [0.0000 0.0004 -0.0036 0.0000 0.0000 0.0000 0.0010 -0.0036 0.0000 -0.0010 0.0000 -0.0000 -0.0001 0.0008 0.0000 -0.0000 -0.0036 -0.0000 0.0000 0.0000 0.0432 0.0419 0.0450 0.0106 0.0116 0.0506 0.0280 0.0338 0.0367 0.0433 0.0242 0.0459 0.0433 0.0034 0.0367 0.0544 0.0036 0.0261 0.0188 0.0495 0.0183 0.0256 0.0157 0.2230 0.1814 0.0260 0.0004 0.1713 0.2326 0.0260 -0.0028 0.2473 0.1879 0.0259 0.0005 0.2286 0.1499 0.0092 0.0002 0.1516 0.1852 0.1874 0.1423 0.1891 0.1966 0.1675 0.2030 0.0752 0.1747 0.1683 0.0751 0.1423 0.1597 0.0823 0.1262 0.1893 0.1270 0.2287 0.1371 0.1874 0.0129 0.0111 -0.0072 0.0047 -0.0103 0.0042 0.0048 0.0058 0.0093 0.0044 0.0315 0.0033 0.0103 0.0069 -0.0042 0.0150 0.0015 0.0046 0.0161 0.0030 0.0265 0.0336 0.0218 0.0229 0.0005 -0.0017 0.0235 -0.0038 0.0121 0.0123 0.0114 0.0111 0.0404 -0.0050 0.0102 0.0154 0.0216 0.0110 0.0136 0.0217 0.0126 0.0000 0.0000 0.0316 0.0011 0.0049 0.0045 0.0125 0.0003 0.0131 0.0174 0.0011 0.0000 0.0013 0.0052 0.0131 0.0072 0.0011 0.0056 0.0000 -0.0028 0.0332 -0.0018 0.0007 0.0195 0.0041 0.0168 0.0193 0.0007 0.0002 0.0372 0.0001 0.0001 0.0212 -0.0018 0.0015 0.0387 0.0005 0.0007 0.0262];
types = {'L1','L2','L3','L4','L5','L6','L7','L8'};
names = {'Preproc.','Split','Look-ahead','Target','Imputation','CV','Tuning','Decomp.'};
thr = 0.01;

fig = newFig(3.5, 2.75);
ax = axes(fig,'Position',[0.14 0.19 0.84 0.77]); hold(ax,'on'); styleAxes(ax,S);
b = boxchart(ax, grp, delta, 'BoxFaceColor',S.c7B, 'BoxFaceAlpha',0.18, ...
    'WhiskerLineColor',S.c7B, 'MarkerStyle','none', 'BoxWidth',0.55, 'LineWidth',0.6);
rng(1);
jit = (rand(size(delta))-0.5)*0.36;
conf = delta > thr;
scatter(ax, grp(~conf)+jit(~conf), delta(~conf), 7, S.light*0.8, 'filled', 'MarkerFaceAlpha',0.9);
scatter(ax, grp(conf)+jit(conf), delta(conf), 7, S.c7B, 'filled', 'MarkerFaceAlpha',0.9);
yline(ax,0,'-','Color',[0.6 0.6 0.6],'LineWidth',0.5);
yline(ax,thr,'--','Color',[0.75 0.2 0.2],'LineWidth',0.6);
text(ax,3.55,thr+0.006,'{\Delta}NSE = 0.01','FontName',S.font,'FontSize',6.5,'Color',[0.75 0.2 0.2], ...
    'HorizontalAlignment','left');
for k = 1:8
    v = delta(grp==k);
    text(ax,k,max(v)+0.014,sprintf('%d%%',round(100*mean(v>thr))),'FontName',S.font, ...
        'FontSize',6.5,'HorizontalAlignment','center');
end
xlim(ax,[0.4 8.6]); ylim(ax,[-0.02 0.275]);
xticks(ax,1:8);
xticklabels(ax, types);
ylabel(ax,'{\Delta}NSE (leaky - clean twin)');
text(ax,8.5,0.215,{'% = share of pairs','with {\Delta}NSE > 0.01'},'FontName',S.font,'FontSize',6.5, ...
    'HorizontalAlignment','right');
for k = 1:8   % short type names under the tick labels
    text(ax,k,-0.049,names{k},'FontName',S.font,'FontSize',6,'HorizontalAlignment','center','VerticalAlignment','top', ...
        'Color',[0.35 0.35 0.35],'Clipping','off');
end
exportFig(fig,'Fig2_Oracle_Inflation');

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
