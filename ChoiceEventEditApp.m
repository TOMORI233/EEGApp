classdef ChoiceEventEditApp < handle
    properties
        UIFigure matlab.ui.Figure
        StartEdit matlab.ui.control.NumericEditField
        JitterAEdit matlab.ui.control.NumericEditField
        JitterBEdit matlab.ui.control.NumericEditField
        WindowEdit matlab.ui.control.NumericEditField
        KeysEdit matlab.ui.control.EditField
        OKButton matlab.ui.control.Button
        CancelButton matlab.ui.control.Button

        ev struct
        onCommit function_handle
    end

    methods
        function app = ChoiceEventEditApp(ev, onCommit)
            app.ev = ev;
            app.onCommit = onCommit;
            app.buildUI_();
            app.load_();
        end

        function showModal(app, ~)
            app.UIFigure.WindowStyle = 'modal';
            app.UIFigure.Visible = 'on';
            movegui(app.UIFigure,'center');
        end
    end

    methods (Access=private)
        function buildUI_(app)
            app.UIFigure = uifigure('Name','Edit Choice Event','Position',[260 260 420 240],'Visible','off');
            gl = uigridlayout(app.UIFigure,[6 2]);
            gl.RowHeight = {26,26,26,26,'1x',34};
            gl.ColumnWidth = {150,'1x'};

            uilabel(gl,'Text','Start time (s):');
            app.StartEdit = uieditfield(gl,'numeric');

            uilabel(gl,'Text','Start jitter A (s):');
            app.JitterAEdit = uieditfield(gl,'numeric');

            uilabel(gl,'Text','Start jitter B (s):');
            app.JitterBEdit = uieditfield(gl,'numeric');

            uilabel(gl,'Text','Valid window (s):');
            app.WindowEdit = uieditfield(gl,'numeric');

            uilabel(gl,'Text','Valid keys (comma):');
            app.KeysEdit = uieditfield(gl,'text');

            app.OKButton = uibutton(gl,'Text','OK','ButtonPushedFcn',@(~,~)app.ok_());
            app.CancelButton = uibutton(gl,'Text','Cancel','ButtonPushedFcn',@(~,~)delete(app.UIFigure));
        end

        function load_(app)
            app.StartEdit.Value = app.ev.tStart;
            app.JitterAEdit.Value = app.ev.jitterA;
            app.JitterBEdit.Value = app.ev.jitterB;
            if ~isfinite(app.ev.validWindow) || app.ev.validWindow<=0, app.ev.validWindow = 1.0; end
            app.WindowEdit.Value = app.ev.validWindow;
            app.KeysEdit.Value = char(app.ev.validKeys);
        end

        function ok_(app)
            app.ev.tStart = app.StartEdit.Value;
            app.ev.jitterA = app.JitterAEdit.Value;
            app.ev.jitterB = app.JitterBEdit.Value;
            app.ev.validWindow = app.WindowEdit.Value;
            app.ev.validKeys = string(app.KeysEdit.Value);

            app.onCommit(app.ev);
            delete(app.UIFigure);
        end
    end
end
