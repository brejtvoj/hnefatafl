function hnefatafl
%% Window size
hRoot = groot;
hRoot.Units = 'pixels';
screenSize = hRoot.ScreenSize(3:4);
sideSize = screenSize(2)-80;
panelSize = 150;
windowSize = [(screenSize(1)-screenSize(2))/2 40 sideSize + panelSize sideSize];

%% Figure creation
hFig = uifigure('Name', 'Hnefatafl', 'pos', windowSize, 'Color', [1 1 1]);
hFig.WindowButtonDownFcn = @mouseClick;

addprop(hFig, 'playfield');
addprop(hFig, 'isDefenderTurn');
addprop(hFig, 'playfieldCaptureBonus');
addprop(hFig, 'selection');
addprop(hFig, 'oldCurrentPoint');

hFig.selection = true;
[hFig.playfield, hFig.isDefenderTurn, hFig.playfieldCaptureBonus] = createPlayfield;

%% Axes creation
hAxes = uiaxes('parent', hFig, 'pos', [100+panelSize -50 sideSize sideSize]);
set(hAxes, 'xtick', []); set(hAxes, 'ytick', []);
hAxes.Box = 'off';
hAxes.BackgroundColor = 'white';
hAxes.XColor = 'white';
hAxes.YColor = 'white';

%% Addition functionality
% Label for current turn
hTurnLabel = uilabel(hFig, 'pos', [50 sideSize-150 panelSize 100]);
hTurnLabel.FontSize = 20;
hTurnLabel.HorizontalAlignment = 'center';
hTurnLabel.Text = "Defender's turn";

%Label for selection status
hSelectionLabel = uilabel(hFig, 'pos', [50 sideSize-200 panelSize 100]);
hSelectionLabel.FontSize = 18;
hSelectionLabel.HorizontalAlignment = 'center';
hSelectionLabel.Text = "Select: Origin";


%Button for reseting the game
hButtonReset = uibutton(hFig, 'Text', 'Reset game', 'pos', [round(panelSize/2) sideSize-250 100 50]);
hButtonReset.ButtonPushedFcn = @resetGame;

%Button for ending the game
hButtonEnd = uibutton(hFig, 'Text', 'Exit', 'pos', [round(panelSize/2) sideSize-350 100 50]);
hButtonEnd.ButtonPushedFcn = @endGame;

%% Data sharing
addprop(hFig, 'axes');
addprop(hFig, 'resetButton');
addprop(hFig, 'exitButton');
addprop(hFig, 'turnLabel');
addprop(hFig, 'selectionLabel');

hFig.axes = hAxes;
hFig.resetButton = hButtonReset;
hFig.exitButton = hButtonEnd;
hFig.turnLabel = hTurnLabel;
hFig.selectionLabel = hSelectionLabel;

%% Pixel graphics
addprop(hFig, 'imgEmpty');
addprop(hFig, 'imgDefender');
addprop(hFig, 'imgAttacker');
addprop(hFig, 'imgKing');
addprop(hFig, 'imgSpecial');
addprop(hFig, 'graphicsArray');

hFig.imgEmpty = imread('bg.jpg');
hFig.imgDefender = imread('def.jpg');
hFig.imgAttacker = imread('att.jpg');
hFig.imgKing = imread('kg.jpg');
hFig.imgSpecial = imread('sp.jpg');

picDim = length(hFig.imgEmpty);
hFig.graphicsArray = uint8(zeros(picDim*11,picDim*11,3));

graphicsUpdate(hFig);

%% Functions
    function mouseClick(hFig, ~)
        
        %Get current point and transform it to coordinates
        point = hFig.axes.CurrentPoint(1,1:2);
        [x, y] = transformCurrentPoint(point, hFig);
        
        graphicsUpdate(hFig); %Removes highlighted tiles
        
        % Check if it's turn to select -> Check if selected piece is on team of the
        % current player
        if(hFig.selection && isPlayable(hFig, x, y))
            hFig.oldCurrentPoint = [x,y]; %Save origin for later use
            hFig.selection = false; % Switch selection mode
            hFig.selectionLabel.Text = "Select: Destination";
            highlightImage(hFig); %Highlight tiles that can be moved to
        elseif(~hFig.selection)
            hFig.selectionLabel.Text = "Select: Origin";
            hFig.selection = true;
            if(isMovable(hFig, x, y)) % Check if selected piece is movable to selected destination
                
                movePiece(hFig, x, y); % Move the piece
                
                %Check if any surrounding pieces are captured
                eliminateCaptured(hFig, x, y, 'up');
                eliminateCaptured(hFig, x, y, 'down');
                eliminateCaptured(hFig, x, y, 'right');
                eliminateCaptured(hFig, x, y, 'left');
                
                %Update Graphics
                graphicsUpdate(hFig);
            end
        end
    end

    function resetGame(hButtonReset, ~) %Revert all setting to initial values
        hFig = hButtonReset.Parent;
        hFig.selection = true;
        [hFig.playfield, hFig.isDefenderTurn, hFig.playfieldCaptureBonus] = createPlayfield;
        graphicsUpdate(hFig);
        picDim = length(hFig.imgEmpty);
        hFig.graphicsArray = uint8(zeros(11*picDim,11*picDim,3));
        hFig.turnLabel.Text = "Defender's turn";
        hFig.selectionLabel.Text = "Select: Origin";
    end

    function endGame(hButtonEnd, ~) %End game
        delete(hButtonEnd.Parent);
    end

    function [x, y] = transformCurrentPoint(point, hFig) % Transform cursor location into coordinates
        x=point(1); y=point(2);
        
        pixelCount = 11 * length(hFig.imgEmpty);
        
        if(x>pixelCount)
            x=pixelCount;
        end
        if(x<0)
            x=0;
        end
        
        if(y>pixelCount)
            y=pixelCount;
        end
        if(y<0)
            y=0;
        end
        
        x=floor(x/(pixelCount/11))+1;
        y=floor(y/(pixelCount/11))+1;
        
        if(x>11)
            x=11;
        end
        if(x<0)
            x=0;
        end
        if(y>11)
            y=11;
        end
        if(y<0)
            y=0;
        end
        
    end

    function [playfield, isDefenderTurn, playfieldCaptureBonus] = createPlayfield % Creates initial values
        playfield = zeros(11);
        KING = 1; DEFENDER = 2; ATTACKER = 3;
        
        %DEFENDERS ----------------------------------------------------------------
        playfield(6,4:8) = DEFENDER; playfield(4:8, 6) = DEFENDER;
        playfield(5:7,5:7) = DEFENDER;
        playfield(6,6) = KING;
        % -------------------------------------------------------------------------
        
        %ATTACKERS ----------------------------------------------------------------
        attackerPrefab = zeros(2,5);
        attackerPrefab(2,:) = ATTACKER; attackerPrefab(1,3) = ATTACKER;
        
        playfield(4:8,1:2) = rot90(attackerPrefab,-1);
        playfield(10:11,4:8) = attackerPrefab;
        playfield(4:8, 10:11) = rot90(attackerPrefab,1);
        playfield(1:2,4:8) = rot90(attackerPrefab,2);
        %--------------------------------------------------------------------------
        
        %Create a second field with values for capture
        BLOCKED_POSITION = -1;
        playfieldCaptureBonus = zeros(13);
        playfieldCaptureBonus([1,end], (1:end)) = BLOCKED_POSITION;
        playfieldCaptureBonus((1:end), [1,end]) = BLOCKED_POSITION;
        playfieldCaptureBonus(7,7) = BLOCKED_POSITION;
        
        %Only the king can enter this tile
        playfieldCaptureBonus([2,end-1],[2,end-1]) = BLOCKED_POSITION;
        
        isDefenderTurn = true; %Default starting turn
    end

    function [returnVal] = isPlayable(hFig, x, y) % Check if piece coresponds with turn
        if(hFig.isDefenderTurn == true) %Check for defender pieces
            if(hFig.playfield(y,x) == 1 || hFig.playfield(y,x) == 2)
                returnVal = 1;
            else
                returnVal = 0;
            end
        else %Check for attacker pieces
            if(hFig.playfield(y,x) == 3)
                returnVal = 1;
            else
                returnVal = 0;
            end
        end
    end

    function [returnVal] = isMovable(hFig, x, y) %Check if piece can move
        
        playfield = hFig.playfield;
        x_old = hFig.oldCurrentPoint(1); y_old = hFig.oldCurrentPoint(2);
        
        if(x == x_old && y == y_old)
            hFig.selection = true; % Invalid point, reset selection
            returnVal = 0;
            return;
        end
        
        if(playfield(y_old, x_old) ~= 1) % Only king can enter the edges and the throne
            if(hFig.playfieldCaptureBonus(y+1,x+1) == -1)
                hFig.selection = true;
                returnVal = 0;
                return;
            end
        end
        
        %Check if no pieces are in the way
        clearway = -1;
        if(x_old == x)
            if(y>y_old)
                clearway = sum(playfield(y_old+1:y, x));
            else
                clearway = sum(playfield(y:y_old-1, x));
            end
        end
        
        if(y_old == y)
            if(x>x_old)
                clearway = sum(playfield(y, x_old+1:x));
            else
                clearway = sum(playfield(y, x:x_old-1));
            end
        end
        
        %Change text and values depending on pieces blocking the way
        if(clearway == 0)
            returnVal = 1;
            hFig.selection = true;
            if(hFig.isDefenderTurn == true)
                hFig.turnLabel.Text = "Attacker's turn";
                hFig.isDefenderTurn = false;
            else
                hFig.turnLabel.Text = "Defender's turn";
                hFig.isDefenderTurn = true;
            end
        else
            returnVal = 0;
        end
        
    end

    function [returnVal] = isMovableHighlight(hFig, x, y) %Simpifield isMovable for highlight
        
        playfield = hFig.playfield;
        x_old = hFig.oldCurrentPoint(1); y_old = hFig.oldCurrentPoint(2);
        
        if(x == x_old && y == y_old)
            returnVal = true;
            return;
        end
        
        if(playfield(y_old, x_old) ~= 1) % Only king can enter the edges and the throne
            if(hFig.playfieldCaptureBonus(y+1,x+1) == -1)
                returnVal = false;
                return;
            end
        end
        
        %Check if no pieces are in the way
        clearway = -1;
        if(x_old == x)
            if(y>y_old)
                clearway = sum(playfield(y_old+1:y, x));
            else
                clearway = sum(playfield(y:y_old-1, x));
            end
        end
        
        if(y_old == y)
            if(x>x_old)
                clearway = sum(playfield(y, x_old+1:x));
            else
                clearway = sum(playfield(y, x:x_old-1));
            end
        end
        
        if(clearway == 0)
            returnVal = true;
        else
            returnVal = false;
        end
        
    end

    function highlightImage(hFig) %Tint tiles yellow if selected piece can move onto it
        
        x_old = hFig.oldCurrentPoint(1); y_old = hFig.oldCurrentPoint(2);
        tileSize = length(hFig.imgEmpty);
        
        y=y_old;
        for x=1:11
            if(isMovableHighlight(hFig, x, y) == true)
                hFig.graphicsArray(tileSize*(y-1)+1:tileSize*(y),tileSize*(x-1)+1:tileSize*(x), [1 2]) = ...
                    hFig.graphicsArray(tileSize*(y-1)+1:tileSize*(y),tileSize*(x-1)+1:tileSize*(x), [1 2])+35;
            end
        end
        
        x=x_old;
        for y=1:11
            if(isMovableHighlight(hFig, x, y) == true)
                hFig.graphicsArray(tileSize*(y-1)+1:tileSize*(y),tileSize*(x-1)+1:tileSize*(x), [1 2]) = ...
                    hFig.graphicsArray(tileSize*(y-1)+1:tileSize*(y),tileSize*(x-1)+1:tileSize*(x), [1 2])+35;
            end
        end
        
        image(hFig.axes, hFig.graphicsArray);
        
    end

    function eliminateCaptured (hFig, x, y, way) %Check if the piece across is eliminated
        xB = x + 1; yB = y + 1; %Transform points for playfieldCaptureBonus
        
        start = hFig.playfield(y,x);
        middle = -1;
        final = 0;
        
        
        %Load correct pieces
        switch way
            case "up"
                if(y ~= 1)
                    if(hFig.playfieldCaptureBonus(yB-1, xB) ~= -1)
                        middle = hFig.playfield(y-1,x);
                    end
                    if(y ~= 2)
                        final = hFig.playfield(y-2,x);
                    end
                    if(y == 3 && hFig.playfieldCaptureBonus(yB-2,xB) == -1)
                        final = hFig.playfieldCaptureBonus(yB-2, xB);
                    end
                    if(x == 6 && y==8 && hFig.playfield(6,6)~=1)
                        final = -1;
                    end
                    if(x == 6 && y==7 && hFig.playfield(6,6) == 1)
                        middle = 1;
                    end
                end
            case "down"
                if(y ~= 11)
                    if(hFig.playfieldCaptureBonus(yB+1, xB) ~= -1)
                        middle = hFig.playfield(y+1,x);
                    end
                    if(y ~= 10)
                        final = hFig.playfield(y+2,x);
                    end
                    if(y == 9 && hFig.playfieldCaptureBonus(yB+2,xB) == -1)
                        final = hFig.playfieldCaptureBonus(yB+2, xB);
                    end
                    if(x == 6 && y==4 && hFig.playfield(6,6)~=1)
                        final = -1;
                    end
                    if(x == 6 && y==5 && hFig.playfield(6,6) == 1)
                        middle = 1;
                    end
                end
            case "right"
                if(x ~= 11)
                    if(hFig.playfieldCaptureBonus(yB, xB+1) ~= -1)
                        middle = hFig.playfield(y,x+1);
                    end
                    if(x ~= 10)
                        final = hFig.playfield(y,x+2);
                    end
                    if(x == 9 && hFig.playfieldCaptureBonus(yB,xB+2) == -1)
                        final = hFig.playfieldCaptureBonus(yB, xB+2);
                    end
                    if(x == 4 && y == 6 && hFig.playfield(6,6)~=1)
                        final = -1;
                    end
                    if(x == 5 && y == 6 && hFig.playfield(6,6) == 1)
                        middle = 1;
                    end
                end
            case "left"
                if(x ~= 1)
                    if(hFig.playfieldCaptureBonus(yB, xB-1) ~= -1)
                        middle = hFig.playfield(y,x-1);
                    end
                    if(x ~= 2)
                        final = hFig.playfield(y,x-2);
                    end
                    if(x == 3 && hFig.playfieldCaptureBonus(yB,xB-2) == -1)
                        final = hFig.playfieldCaptureBonus(yB, xB-2);
                    end
                    if(x == 8 && y==6 && hFig.playfield(6,6)~=1)
                        final = -1;
                    end
                    if(x == 7 && y==6 && hFig.playfield(6,6) == 1)
                        middle = 1;
                    end
                end
        end
        
        %Check if pieces across can capture piece in the middle
        captured = false;
        if(start == 1 || start == 2)
            if(final == 1 || final == 2 || final == -1)
                if(middle == 3)
                    captured = true;
                end
            end
        end
        
        if(start == 3)
            if(final == 3 || final == -1)
                if(middle == 2)
                    captured = true;
                end
            end
        end
        
        if(middle == 1)
            if(isKingCaptured(hFig))
                gameOver(hFig, false);
            end
        end
        
        if(captured == true && middle ~= -1)
            switch way
                case "up"
                    hFig.playfield(y-1,x) = 0;
                case "down"
                    hFig.playfield(y+1,x) = 0;
                case "left"
                    hFig.playfield(y,x-1) = 0;
                case "right"
                    hFig.playfield(y,x+1) = 0;
            end
        end
        
    end

    function [returnVal] = isKingCaptured(hFig) %Find the king and check surrounding pieces for capture
        returnVal = false;
        
        [y,x] = find(hFig.playfield == 1);
        xB = x+1; yB = y+1;
        
        aroundPieces = zeros(1,4);
        
        if(y~=1)
            aroundPieces(1) = hFig.playfieldCaptureBonus(yB-1,xB);
        end
        if(y~=11)
            aroundPieces(2) = hFig.playfieldCaptureBonus(yB+1,xB);
        end
        if(x~=1)
            aroundPieces(3) = hFig.playfieldCaptureBonus(yB,xB-1);
        end
        if(x~=11)
            aroundPieces(4) = hFig.playfieldCaptureBonus(yB,xB+1);
        end
        
        if(y~=1 && aroundPieces(1)~=-1)
            aroundPieces(1) = hFig.playfield(y-1,x);
        end
        if(y~=11 &&aroundPieces(2) ~= -1)
            aroundPieces(2) = hFig.playfield(y+1,x);
        end
        if(x~=1 &&aroundPieces(3) ~= -1)
            aroundPieces(3) = hFig.playfield(y,x-1);
        end
        if(x~=11 &&aroundPieces(4) ~= -1)
            aroundPieces(4) = hFig.playfield(y,x+1);
        end
        
        enemyCount = length(find(aroundPieces == 3 | aroundPieces == -1));
        if(enemyCount == 4)
            returnVal = true;
        end
    end

    function movePiece(hFig, x, y) %Move the
        hFig.playfield(y,x) = hFig.playfield(hFig.oldCurrentPoint(2), hFig.oldCurrentPoint(1));
        hFig.playfield(hFig.oldCurrentPoint(2), hFig.oldCurrentPoint(1)) = 0;
        
        if(hFig.playfield(y, x) == 1) %King entered the corner
            if(hFig.playfieldCaptureBonus(y+1, x+1) == -1 && x ~= 6)
                gameOver(hFig, true);
            end
        end
        
    end

    function gameOver(hFig, isDefenderWin) %End game
        
        if(isDefenderWin == true)
            hFig.turnLabel.Text = "Defenders WIN!";
        else
            hFig.turnLabel.Text = "Attackers WIN!";
        end
        hFig.selectionLabel.Text = "";
        hFig.playfield = zeros(11);
        graphicsUpdate(hFig);
    end

    function graphicsUpdate(hFig) %Update graphics
        
        tileSize = length(hFig.imgEmpty);
        for x=1:11
            for y=1:11
                switch(hFig.playfield(y,x))
                    case 0
                        hFig.graphicsArray(tileSize*(y-1)+1:tileSize*(y),tileSize*(x-1)+1:tileSize*(x), :) = hFig.imgEmpty;
                    case 1
                        hFig.graphicsArray(tileSize*(y-1)+1:tileSize*(y),tileSize*(x-1)+1:tileSize*(x), :) = hFig.imgKing;
                    case 2
                        hFig.graphicsArray(tileSize*(y-1)+1:tileSize*(y),tileSize*(x-1)+1:tileSize*(x), :) = hFig.imgDefender;
                    case 3
                        hFig.graphicsArray(tileSize*(y-1)+1:tileSize*(y),tileSize*(x-1)+1:tileSize*(x), :) = hFig.imgAttacker;
                end
            end
        end
        
        
        if(hFig.playfield(6, 6) ~= 1 )
            x=6; y=6;
            hFig.graphicsArray(tileSize*(y-1)+1:tileSize*(y),tileSize*(x-1)+1:tileSize*(x), :) = hFig.imgSpecial;
        end
        if(hFig.playfield(1, 1) ~= 1 )
            x=[1, 11]; y=[1, 11];
            hFig.graphicsArray(tileSize*(y-1)+1:tileSize*(y),tileSize*(x-1)+1:tileSize*(x), :) = hFig.imgSpecial;
        end
        if(hFig.playfield(1, 11) ~= 1 )
            x=1; y=11;
            hFig.graphicsArray(tileSize*(y-1)+1:tileSize*(y),tileSize*(x-1)+1:tileSize*(x), :) = hFig.imgSpecial;
        end
        if(hFig.playfield(11, 1) ~= 1 )
            x=11; y=1;
            hFig.graphicsArray(tileSize*(y-1)+1:tileSize*(y),tileSize*(x-1)+1:tileSize*(x), :) = hFig.imgSpecial;
        end
        if(hFig.playfield(11, 11) ~= 1 )
            x=11; y=11;
            hFig.graphicsArray(tileSize*(y-1)+1:tileSize*(y),tileSize*(x-1)+1:tileSize*(x), :) = hFig.imgSpecial;
        end
        
        image(hFig.axes, hFig.graphicsArray);
        
        
    end

end
