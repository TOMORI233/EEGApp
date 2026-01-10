classdef StartEventEditApp < handle
    properties
        UIFigure matlab.ui.Figure
        ModeDropDown matlab.ui.control.DropDown
        KeyEdit matlab.ui.control.EditField
        OKButton matlab.ui.control.Button
        CancelButton matlab.ui.control.Button
        JitterAEdit matlab.ui.control.NumericEditField
        JitterBEdit matlab.ui.control.NumericEditField

        ev struct
        onCommit function_handle
    end

    methods
        function app = StartEventEditApp(ev, onCommit)
            app.ev = ev;
            app.onCommit = onCommit;
            app.buildUI_();
            app.load_();
        end

        function showModal(app, parentFig)
            app.UIFigure.WindowStyle = 'modal';
            app.UIFigure.Visible = 'on';
            if nargin>1 && ~isempty(parentFig)
                movegui(app.UIFigure,'center');
            end
        end
    end

    methods (Access=private)
        function buildUI_(app)
            app.UIFigure = uifigure('Name','Edit Start Event', 'Position',[200 200 360 220], 'Visible','off');
            
            gl = uigridlayout(app.UIFigure,[6 2]);
            gl.RowHeight   = {24,24,24,24,'1x',30};
            gl.ColumnWidth = {120,'1x'};
            gl.Padding     = [10 10 10 10];
            gl.RowSpacing  = 6;
            gl.ColumnSpacing = 8;

            uilabel(gl,'Text','Trigger mode:');
            app.ModeDropDown = uidropdown(gl,'Items',{'auto','keyboard'}, ...
                'ValueChangedFcn',@(s,e)app.onModeChanged_());

            uilabel(gl,'Text','Key (keyboard):');
            app.KeyEdit = uieditfield(gl,'text');

            uilabel(gl,'Text','Start jitter A (s):');
            app.JitterAEdit = uieditfield(gl,'numeric');
            
            uilabel(gl,'Text','Start jitter B (s):');
            app.JitterBEdit = uieditfield(gl,'numeric');

            lbl = uilabel(gl, ...
                'Text','Note: Jitter only changes the inter-trial interval.', ...
                'FontAngle','italic', ...
                'WordWrap','on', ...
                'HorizontalAlignment','left');
            lbl.Layout.Column = [1 2];

            app.OKButton = uibutton(gl,'Text','OK','ButtonPushedFcn',@(~,~)app.ok_());
            app.CancelButton = uibutton(gl,'Text','Cancel','ButtonPushedFcn',@(~,~)delete(app.UIFigure));
        end

        function load_(app)
            if strlength(app.ev.triggerMode)==0
                app.ev.triggerMode = "auto";
            end
            app.ModeDropDown.Value = char(app.ev.triggerMode);
            app.KeyEdit.Value = char(app.ev.triggerKey);
            app.onModeChanged_();
            app.JitterAEdit.Value = app.ev.jitterA;
            app.JitterBEdit.Value = app.ev.jitterB;
        end

        function onModeChanged_(app)
            isKb = strcmp(app.ModeDropDown.Value,'keyboard');
            app.KeyEdit.Enable = matlab.lang.OnOffSwitchState(isKb);
        end

        function ok_(app)
            app.ev.kind = "start";
            app.ev.tStart = 0; app.ev.tEnd = 0;
            app.ev.triggerMode = string(app.ModeDropDown.Value);
            app.ev.triggerKey = string(app.KeyEdit.Value);
            if app.ev.triggerMode=="auto"
                app.ev.triggerKey = "";
            end
            app.ev.jitterA = app.JitterAEdit.Value;
            app.ev.jitterB = app.JitterBEdit.Value;

            app.onCommit(app.ev);
            delete(app.UIFigure);
        end
    end
end
