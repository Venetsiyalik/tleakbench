%% Fig4_PerType_Recall.m
% Recall per leakage type for every model/method (rows: L1-L8).
% Self-contained: run once -> Fig4_PerType_Recall.png (600 dpi) + .pdf
clear; close all;
S = figStyle();
R = [1.00 1.00 0.95 1.00 0.05 0.75 0.75 1.00 1.00;
       1.00 1.00 0.95 1.00 0.00 1.00 1.00 0.90 1.00;
       1.00 1.00 0.80 1.00 0.00 0.90 0.85 0.75 1.00;
       1.00 1.00 1.00 1.00 0.00 0.85 0.80 1.00 1.00;
       1.00 1.00 0.70 1.00 0.05 0.80 0.95 0.90 1.00;
       1.00 1.00 0.85 0.65 0.00 0.65 0.90 0.80 1.00;
       1.00 1.00 0.75 0.95 0.00 1.00 1.00 0.95 1.00;
       1.00 1.00 0.95 1.00 0.05 0.80 0.90 1.00 1.00];
rowLab = {'L1 Preproc.','L2 Split','L3 Look-ahead','L4 Target','L5 Imputation','L6 CV','L7 Tuning','L8 Decomp.'};
colLab = {'3B B0','3B B1','3B B2','3B B4','7B B0','7B B1','7B B2','7B B4','B3 static'};
fpr    = [1.00 1.00 0.80 0.85 0.00 0.83 0.84 0.59 0.00];   % false-positive rate on 80 clean items

fig = newFig(3.5, 3.0);
ax = axes(fig,'Position',[0.25 0.25 0.59 0.68]);
imagesc(ax,R); caxis(ax,[0 1]);
styleAxes(ax,S);   % after imagesc (imagesc resets axes properties)
set(ax,'Box','on');
n = 256; base = S.c7B;
cmap = [linspace(1,base(1),n)', linspace(1,base(2),n)', linspace(1,base(3),n)'];
colormap(ax,cmap);
for i = 1:size(R,1)
    for j = 1:size(R,2)
        if R(i,j) > 0.6, tc = 'w'; else, tc = 'k'; end
        text(ax,j,i,sprintf('%.2f',R(i,j)),'HorizontalAlignment','center','FontName',S.font, ...
            'FontSize',6,'Color',tc);
    end
end
hold(ax,'on');
plot(ax,[4.5 4.5],[0.5 8.5],'k-','LineWidth',0.8);
plot(ax,[8.5 8.5],[0.5 8.5],'k-','LineWidth',0.8);
set(ax,'XTick',1:9,'XTickLabel',colLab,'YTick',1:8,'YTickLabel',rowLab,'TickLength',[0 0]);
xtickangle(ax,45);
ax.XAxisLocation = 'bottom';
cb = colorbar(ax,'Position',[0.86 0.25 0.03 0.68]);
cb.Label.String = 'Recall'; cb.FontName = S.font; cb.FontSize = 7;
% false-positive rate row (context for recall)
for j = 1:9
    text(ax,j,0.05,sprintf('%.2f',fpr(j)),'HorizontalAlignment','center','FontName',S.font, ...
        'FontSize',6,'Color',[0.70 0.15 0.15]);
end
text(ax,0.4,0.05,'FPR','HorizontalAlignment','right','FontName',S.font,'FontSize',6.5, ...
    'Color',[0.70 0.15 0.15]);
ylim(ax,[-0.3 8.5]);
exportFig(fig,'Fig4_PerType_Recall');

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
