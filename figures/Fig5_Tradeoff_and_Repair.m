%% Fig5_Tradeoff_and_Repair.m
% (a) Operating points in ROC space (recall vs false-positive rate);
% (b) oracle-localised repair success per leakage type.
% Self-contained: run once -> Fig5_Tradeoff_and_Repair.png (600 dpi) + .pdf
clear; close all;
S = figStyle();
% recall and FPR (FPR = mean of clean and hard-negative FPR, 80 clean items)
rec3 = [1.000 1.000 0.869 0.950];  fpr3 = [1.000 1.000 0.800 0.850];
rec7 = [0.019 0.844 0.894 0.912];  fpr7 = [0.000 0.825 0.8375 0.5875];
lab  = {'B0','B1','B2','B4'};
rep3 = [0.20 0.35 0.00 0.00 1.00 0.00 0.00 0.00];   % repair success per type, 3B
rep7 = [0.65 0.95 0.15 0.00 0.30 0.65 0.00 0.20];   % repair success per type, 7B
types = {'L1','L2','L3','L4','L5','L6','L7','L8'};

fig = newFig(3.5, 4.3);
t = tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');

% (a) ROC space
ax = nexttile(t); hold(ax,'on'); styleAxes(ax,S);
plot(ax,[0 1],[0 1],':','Color',[0.55 0.55 0.55],'LineWidth',0.7);
h1 = scatter(ax,fpr3,rec3,22,S.c3B,'filled','Marker','s');
h2 = scatter(ax,fpr7,rec7,24,S.c7B,'filled','Marker','o');
h3 = scatter(ax,0,1,40,S.cSt,'filled','Marker','p');
% crowded upper-right cluster: labels stacked to the right with leader lines
P   = [fpr3(1) rec3(1); fpr3(4) rec3(4); fpr7(3) rec7(3); fpr3(3) rec3(3); fpr7(2) rec7(2)];
L   = {'3B B0, B1','3B B4','7B B2','3B B2','7B B1'};
C   = [S.c3B; S.c3B; S.c7B; S.c3B; S.c7B];
yl  = [0.80 0.72 0.64 0.56 0.48];
for k = 1:5
    plot(ax,[P(k,1) 0.885],[P(k,2) yl(k)],'-','Color',[C(k,:) 0.5],'LineWidth',0.4);
    text(ax,0.89,yl(k),L{k},'FontName',S.font,'FontSize',6.5,'Color',C(k,:));
end
text(ax,fpr7(4)-0.025,rec7(4),'7B B4','FontName',S.font,'FontSize',6.5,'Color',S.c7B,'HorizontalAlignment','right');
text(ax,fpr7(1)+0.03,rec7(1)+0.03,'7B B0','FontName',S.font,'FontSize',6.5,'Color',S.c7B);
text(ax,0.04,0.93,'B3 static','FontName',S.font,'FontSize',6.5,'Color',S.cSt);
text(ax,0.62,0.52,'chance','FontName',S.font,'FontSize',6.5,'Color',[0.5 0.5 0.5],'Rotation',43);
xlim(ax,[-0.03 1.12]); ylim(ax,[-0.03 1.08]); axis(ax,'square');
xlabel(ax,'False-positive rate (clean + hard negatives)'); ylabel(ax,'Recall');
legend(ax,[h1 h2 h3],{'Qwen2.5-Coder-3B','Qwen2.5-Coder-7B','B3 static rules'}, ...
    'Location','southeast','Box','off','FontSize',6.5);
title(ax,'(a) Detection operating points','FontWeight','normal','FontSize',8);

% (b) repair
ax = nexttile(t); hold(ax,'on'); styleAxes(ax,S);
hb = bar(ax,1:8,[rep3; rep7]','grouped','BarWidth',0.8,'EdgeColor','none');
hb(1).FaceColor = S.c3B; hb(2).FaceColor = S.c7B;
ylim(ax,[0 1.3]); yticks(ax,0:0.2:1); xlim(ax,[0.45 8.55]); xticks(ax,1:8); xticklabels(ax,types);
ylabel(ax,'Repair success rate');
legend(ax,{'3B (overall 19.4%)','7B (overall 36.2%)'},'Location','north','Box','off','FontSize',6.5, ...
    'NumColumns',2);
title(ax,'(b) Oracle-localised repair (executed and verified)','FontWeight','normal','FontSize',8);

exportFig(fig,'Fig5_Tradeoff_and_Repair');

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
