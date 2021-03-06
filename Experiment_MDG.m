clear all;
close all;
clc;
addpath('./Functions');
Screen('Preference', 'SkipSyncTests', 1);

try
    %===== Parameters =====%

    totalTrials         = 10;
    practiceTrials      = 15;
    
    allocateTime        = 5;
    guessTime1          = 5;
    guessTime2          = 5;
    showResultTime      = 2;
    fixationTime        = 1;
    
    %===== Constants =====%
    TRUE                = 1;
    FALSE               = 0;
    
    %===== IP Config for developing ===%
    
    myIP = 'localhost';
    oppIP = 'localhost';

    rule = input('Rule(player1/player2): ','s');
    assert( strcmp(rule,'player1')|strcmp(rule,'player2'));
    if strcmp(rule,'player1')
        myID = 'test_player1';
        oppID = 'test_player2';
        %myIP = '192.168.1.83';
        %oppIP = '192.168.1.42';
        myPort = 5656;
        oppPort = 7878;
    end
    if(strcmp(rule,'player2'))
        myID = 'test_player2';
        oppID = 'test_player1';
        %myIP = '192.168.1.42';
        %oppIP = '192.168.1.83';
        myPort = 7878;
        oppPort = 5656;
    end
    
%     %===== IP Config for 505 ===%
%     myID = input('This seat: ','s');
%     oppID = input('Opp seat: ','s');
%     fprintf('cmd to open terminal. "IPConfig" to get IP (the one with 172.16.10.xxx)\n');
%     myIP = input('This IP: ','s');
%     myIP = strcat('172.16.10.',myIP);
%     oppIP = input('Opp IP: ','s');
%     oppIP = strcat('172.16.10.',oppIP);
%     myPort = 5454;
%     oppPort = 5454;
%     if myID(2) == 'a' | myID(2)=='A'
%         rule = 'player1';
%     else
%         rule = 'player2';
%     end
    
    %===== Inputs =====%

    fprintf('---Starting Experiment---\n');
    inputDeviceName     = 'Mac';
    screenID            = 0;
    
    if(strcmp(rule,'player1')) displayerOn = TRUE; end
    if(strcmp(rule,'player2')) displayerOn = FALSE; end
    automode = FALSE;
    
    %===== Initialize Componets =====%
    keyboard    = keyboardHandler(inputDeviceName);
    displayer   = displayer(max(Screen('Screens')),displayerOn);
    parser      = parser();
    data        = dataHandler(myID,oppID,rule,totalTrials);
    
    %===== Establish Connection =====% 
    cnt = connector(rule,myID, oppID,myIP,myPort,oppIP,oppPort);
    cnt.establish(myID,oppID);
    if displayerOn
        ListenChar(2);
        HideCursor();
    end
    
    %===== Open Screen =====% 
    fprintf('Start after 10 seconds\n');
    %WaitSecs(10);
    displayer.openScreen();
    
    displayer.writeMessage('Press space to start','');
    fprintf('Press Space to start.\n');
    keyboard.waitSpacePress();
    displayer.blackScreen();
    fprintf('Game Start.\n');
    fprintf('----------------\n');

    %===== Start of real experiment ======%
    
    %generate condition list
    if(strcmp(rule,'player1'))
        data.gen_condList();
        condList = data.get_condList;
        cnt.sendCondList(parser.listToStr(condList));
    end
    
    if(strcmp(rule,'player2'))
        condListStr = cnt.getCondList();
        data.set_condList(parser.strToList(condListStr));
    end

    action = cell(1,3);
    action{1} = 'up';
    action{2} = 'down';
    action{3} = 'confirm';
    action{4} = 'na';
    
    for trial = 1:totalTrials

        invalid_res = 0;
        %=========== Setting Up Trials ==============%
        %Syncing
        if(trial == 1)
            displayer.writeMessage('Waiting for Opponent.','');
            fprintf('Waiting for Opponent.\n');
            cnt.syncTrial(trial);
            displayer.blackScreen();
        else
            cnt.syncTrial(trial);
        end
        
        %display respond package
        myRes.youAreDictator = strcmp(rule,data.getDictator(trial));
        myRes.keepMoney_ori     = -1;
        myRes.givenMoney_ori    = -1;
        myRes.keepMoney         = -1;
        myRes.givenMoney        = -1;
        myRes.disrupt           = data.getDisrupt(trial);
        myRes.s1                = -1;
        myRes.s2                = -1;
        myRes.s3                = -1;
        myRes.allocated         = FALSE;
        myRes.s1answered        = FALSE;
        myRes.s2answered        = FALSE;
        myRes.s3answered        = FALSE;
        myRes.allocateRT        = 0;
        myRes.s1RT              = 0;
        myRes.s2RT              = 0;
        myRes.s3RT              = 0;
        
        %=========== Fixation ==============%
        displayer.fixation(fixationTime);
       
        %=========== Fixation ==============%
        
        if myRes.youAreDictator
            displayer.writeMessage('DICTATOR','');
            WaitSecs(2);
        end
        
        if ~myRes.youAreDictator
            displayer.writeMessage('RECEIVER','');
            WaitSecs(2);
        end
        
        %========== Allocate Money ===============%
        myRes.state  = 'allocate';
        startTime = GetSecs(); 
        decisionMade = FALSE;
        if myRes.youAreDictator
            fprintf('Please Allocate money.\n');
            for elapse = 1:allocateTime
                remaining = allocateTime-elapse+1;
                endOfThisSecond = startTime+elapse;
                fprintf('remaining time: %d\n',remaining);
                displayer.decideScreen(myRes,remaining,decisionMade);
                while(GetSecs()<endOfThisSecond)
                    if ~decisionMade
                       if(automode)
                           keyName = action{randi(4)};
                           timing = 3;
                       else [keyName,timing] = keyboard.getResponse(endOfThisSecond); end
                       
                       if(strcmp(keyName,'na')) continue;
                       else
                           if(strcmp(keyName,'confirm') && myRes.keepMoney ~= -1)
                                myRes.allocateRT = timing;
                                myRes.allocated = TRUE;
                                decisionMade = TRUE;
                                fprintf('confirmed: keep %d$ give %d$\n',myRes.keepMoney);
                                displayer.decideScreen(myRes,remaining,decisionMade);
                           end

                           if strcmp(keyName,'quitkey')
                                displayer.closeScreen();
                                ListenChar();
                                fprintf('---- MANUALLY STOPPED ----\n');
                                return;
                           end
                           
                           try
                              keyName = str2num(keyName);
                              if keyName >= 1 && keyName <=9
                                myRes.keepMoney  = keyName;
                                myRes.givenMoney = 10 - myRes.keepMoney;
                                displayer.decideScreen(myRes,remaining,decisionMade);
                                fprintf('keep: %d$ give: %d$\n',myRes.keepMoney, myRes.givenMoney);
                              end 
                           catch end
                       end
                    end
                end
            end
            displayer.decideScreen(myRes,0,decisionMade);
        end
        
        if ~myRes.youAreDictator
            fprintf('Waiting for dictator to allocate\n');
            for elapse = 1:allocateTime
                remaining = allocateTime-elapse+1;
                endOfThisSecond = startTime+elapse;
                fprintf('remaining time: %d\n',remaining);
                while(GetSecs()<endOfThisSecond)
                    displayer.decideScreen(myRes,remaining,decisionMade);
                end
            end
            displayer.decideScreen(myRes,0,decisionMade);
        end
   
        %========== Sync money ===============%
        
        if(myRes.youAreDictator)
            if(~myRes.allocated)
                myRes.keepMoney = 1;
                myRes.givenMoney = 9;
            end
            
            myRes.keepMoney_ori = myRes.keepMoney;
            myRes.givenMoney_ori = myRes.givenMoney;
            cnt.sendMoney(myRes.keepMoney_ori);
        else
            myRes.keepMoney_ori = cnt.getMoney();
            myRes.givenMoney_ori = 10-myRes.keepMoney_ori;
        end
        
        myRes.keepMoney = myRes.keepMoney_ori + myRes.disrupt;
        if(myRes.keepMoney >9) myRes.keepMoney = 9; end
        if(myRes.keepMoney <1) myRes.keepMoney = 1; end
        myRes.givenMoney = 10-myRes.keepMoney;
        
        %========== Guess1 ===============%
        
        myRes.state  = 'guess1';
        startTime = GetSecs();
        decisionMade = FALSE;
        if myRes.youAreDictator
            fprintf('Please Guess how many heart given to you\n');
            
            for elapse = 1:guessTime1
                remaining = guessTime1-elapse+1;
                endOfThisSecond = startTime+elapse;
                fprintf('remaining time: %d\n',remaining);
                displayer.decideScreen(myRes,remaining,decisionMade);

                while(GetSecs()<endOfThisSecond)
                    if ~decisionMade
                       
                       % get respond
                       if(automode)
                           keyName = action{randi(4)};
                           timing = 3;
                       else
                           [keyName,timing] = keyboard.getResponse(endOfThisSecond);
                       end
                       
                       if(strcmp(keyName,'na'))
                           continue;
                       else
                           if(strcmp(keyName,'confirm'))
                                myRes.s2RT= timing;
                                decisionMade = TRUE;
                                myRes.s2answered = TRUE;
                                fprintf('confirmed: you guess %d heart(s)\n',myRes.s2);
                                displayer.decideScreen(myRes,remaining,decisionMade);
                           end

                           if strcmp(keyName,'quitkey')
                                displayer.closeScreen();
                                ListenChar();
                                fprintf('---- MANUALLY STOPPED ----\n');
                                return;
                           end
                           
                           try
                              keyName = str2num(keyName);
                              if keyName >= 1 && keyName <=7
                                myRes.s2  = keyName;
                                displayer.decideScreen(myRes,remaining,decisionMade);
                                fprintf('%d heart(s).\n',myRes.s2);
                              end 
                           catch
                           end
                           
                       end
                    end
                end
            end
            displayer.decideScreen(myRes,0,decisionMade);
        end
        
        if ~myRes.youAreDictator
            fprintf('Please give hearts to dictator\n');
            for elapse = 1:guessTime1
                remaining = guessTime1-elapse+1;
                endOfThisSecond = startTime+elapse;
                fprintf('remaining time: %d\n',remaining);
                displayer.decideScreen(myRes,remaining,decisionMade);

                while(GetSecs()<endOfThisSecond)
                    if ~decisionMade
                       % get respond
                       if(automode)
                           keyName = action{randi(4)};
                           timing = 3;
                       else
                           [keyName,timing] = keyboard.getResponse(endOfThisSecond);
                       end
                       
                       if(strcmp(keyName,'na'))
                           continue;
                       else
                           if(strcmp(keyName,'confirm'))
                                myRes.s1RT= timing;
                                decisionMade = TRUE;
                                myRes.s1answered = TRUE;
                                fprintf('confirmed: you give %d heart(s)\n',myRes.s1);
                                displayer.decideScreen(myRes,remaining,decisionMade);
                           end

                           if strcmp(keyName,'quitkey')
                                displayer.closeScreen();
                                ListenChar();
                                fprintf('---- MANUALLY STOPPED ----\n');
                                return;
                           end
                           
                           try
                              keyName = str2num(keyName);
                              if keyName >= 1 && keyName <=7
                                myRes.s1  = keyName;
                                displayer.decideScreen(myRes,remaining,decisionMade);
                                fprintf('%d heart(s).\n',myRes.s1);
                              end 
                           catch
                           end
                           
                       end
                    end
                end
            end
            displayer.decideScreen(myRes,0,decisionMade);
        end
        
        %========== Guess2 ===============%
        myRes.state  = 'guess2';
        startTime = GetSecs();
        decisionMade = FALSE;
        if myRes.youAreDictator
            fprintf('Waiting for receiver to guess.\n');
            for elapse = 1:guessTime2
                remaining = guessTime2-elapse+1;
                endOfThisSecond = startTime+elapse;
                fprintf('remaining time: %d\n',remaining);
                while(GetSecs()<endOfThisSecond)
                    displayer.decideScreen(myRes,remaining,decisionMade);
                end
            end
            displayer.decideScreen(myRes,0,decisionMade);
        end    
         
        if ~myRes.youAreDictator
            fprintf('Please Guess dictators guess.\n');
            for elapse = 1:guessTime2
                remaining = guessTime2-elapse+1;
                endOfThisSecond = startTime+elapse;
                fprintf('remaining time: %d\n',remaining);
                displayer.decideScreen(myRes,remaining,decisionMade);

                while(GetSecs()<endOfThisSecond)
                    if ~decisionMade
                        
                       % get respond
                       if(automode)
                           keyName = action{randi(4)};
                           timing = 3;
                       else
                           [keyName,timing] = keyboard.getResponse(endOfThisSecond);
                       end
                       
                       if(strcmp(keyName,'na'))
                           continue;
                       else
                           if(strcmp(keyName,'confirm'))
                                myRes.s3RT= timing;
                                decisionMade = TRUE;
                                myRes.s3answered = TRUE;
                                fprintf('confirmed : you guess %d heart(s).\n',myRes.s3);
                                displayer.decideScreen(myRes,remaining,decisionMade);
                           end

                           if strcmp(keyName,'quitkey')
                                displayer.closeScreen();
                                ListenChar();
                                fprintf('---- MANUALLY STOPPED ----\n');
                                return;
                           end
                           
                           try
                              keyName = str2num(keyName);
                              if keyName >= 1 && keyName <=7
                                myRes.s3  = keyName;
                                displayer.decideScreen(myRes,remaining,decisionMade);
                                fprintf('%d heart(s).\n',myRes.s3);
                              end 
                           catch
                           end
                       end
                    end
                end
            end
            displayer.decideScreen(myRes,0,decisionMade);
        end
        
        myRes.state  = 'delay';
        endTime = GetSecs()+showResultTime;
        while GetSecs() < endTime
            displayer.decideScreen(myRes,0,TRUE);
        end
        
        %========== Exchange and Save Data ===============%
        %Get opponent's response
        oppResRaw = cnt.sendOwnResAndgetOppRes(parser.resToStr(myRes));
        oppRes = parser.strToRes(oppResRaw);
        data.updateData(myRes,oppRes,trial);
        
        %========== Show result ===============%
        WaitSecs(3);
        displayer.blackScreen();
    end
    
    displayer.closeScreen();
    ListenChar();
    data.saveToFile();
    fprintf('----END OF EXPERIMENT----\n');
    
catch exception
    fprintf(1,'Error: %s\n',getReport(exception));
    displayer.closeScreen();
    ListenChar();
    ShowCursor();
end
