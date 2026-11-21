%% Fig3_Detection_Performance.m
% (a) Matthews correlation coefficient and (b) line-localisation accuracy, by method and model.
% Self-contained: run once -> Fig3_Detection_Performance.png (600 dpi) + .pdf
clear; close all;
S = figStyle();
methods = {'B0 plain','B1 taxonomy','B2 CoT','B4 hybrid'};
mcc = [0.000 0.000 0.090 0.171;     % Qwen2.5-Coder-3B (B0,B1: all-positive -> MCC undefined, shown as 0)
       0.080 0.024 0.081 0.385];    % Qwen2.5-Coder-7B
loc = [0.031 0.081 0.062 0.388;
       0.000 0.050 0.119 0.662];
undef3B = [true true false false];

fig = newFig(3.5, 3.6);
t = tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');

% (a) MCC
ax = nexttile(t); hold(ax,'on'); styleAxes(ax,S);
hb = bar(ax,1:4,mcc','grouped','BarWidth',0.8,'EdgeColor','none');
hb(1).FaceColor = S.c3B; hb(2).FaceColor = S.c7B;
for k = 1:2
    for j = 1:4
        if k==1 && undef3B(j), lab = 'n/d'; else, lab = sprintf('%.2f',mcc(k,j)); end
        text(ax,hb(k).XEndPoints(j),mcc(k,j)+0.012,lab,'HorizontalAlignment','center', ...
            'FontName',S.font,'FontSize',6.5);
    end
end
ylim(ax,[0 0.5]); xlim(ax,[0.45 4.55]); xticks(ax,1:4); xticklabels(ax,methods);
ylabel(ax,'MCC');
legend(ax,{'Qwen2.5-Coder-3B','Qwen2.5-Coder-7B'},'Location','northwest','Box','off','FontSize',7);
text(ax,4.5,0.47,'B3 static rules: MCC = 1.00','HorizontalAlignment','right','FontName',S.font, ...
    'FontSize',6.5,'Color',S.cSt);
title(ax,'(a) Detection quality','FontWeight','normal','FontSize',8);

% (b) localisation
ax = nexttile(t); hold(ax,'on'); styleAxes(ax,S);
hb = bar(ax,1:4,loc','grouped','BarWidth',0.8,'EdgeColor','none');
hb(1).FaceColor = S.c3B; hb(2).FaceColor = S.c7B;
for k = 1:2
    for j = 1:4
        text(ax,hb(k).XEndPoints(j),loc(k,j)+0.02,sprintf('%.2f',loc(k,j)),'HorizontalAlignment','center', ...
            'FontName',S.font,'FontSize',6.5);
    end
end
yline(ax,1,'--','Color',S.cSt,'LineWidth',0.6);
text(ax,4.5,0.94,'B3 static rules = 1.00','HorizontalAlignment','right','FontName',S.font, ...
    'FontSize',6.5,'Color',S.cSt);
ylim(ax,[0 1.05]); xlim(ax,[0.45 4.55]); xticks(ax,1:4); xticklabels(ax,methods);
ylabel(ax,'Line localisation accuracy');
title(ax,'(b) Localisation of the leaking statement','FontWeight','normal','FontSize',8);

exportFig(fig,'Fig3_Detection_Performance');

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
