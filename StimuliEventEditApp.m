classdef StimuliEventEditApp < handle
    properties
        UIFigure matlab.ui.Figure

        KindLabel matlab.ui.control.Label
        TypeDropDown matlab.ui.control.DropDown
        StartEdit matlab.ui.control.NumericEditField
        JitterAEdit matlab.ui.control.NumericEditField
        JitterBEdit matlab.ui.control.NumericEditField
        MaxDurEdit matlab.ui.control.NumericEditField
        IdentifierEdit matlab.ui.control.EditField

        OKButton matlab.ui.control.Button
        CancelButton matlab.ui.control.Button

        ev struct
        onCommit function_handle
    end

    methods
        function app = StimuliEventEditApp(ev, onCommit)
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
            app.UIFigure = uifigure( ...
                'Name','Edit Stimuli/Cue Event', ...
                'Position',[250 250 420 300], ...   % 更紧凑
                'Visible','off');

            gl = uigridlayout(app.UIFigure,[8 2]);
            gl.RowHeight = {24,24,24,24,24,24,24,34};
            gl.ColumnWidth = {140,'1x'};
            gl.Padding = [12 12 12 12];
            gl.RowSpacing = 8;
            gl.ColumnSpacing = 10;

            % Row 1: Kind (display only, span 2 columns)
            app.KindLabel = uilabel(gl,'Text','Kind:','FontWeight','bold');
            app.KindLabel.Layout.Column = [1 2];

            % Row 2: Type
            uilabel(gl,'Text','Type (modality):');
            app.TypeDropDown = uidropdown(gl,'Items',{'auditory','visual'});

            % Row 3: Start time
            uilabel(gl,'Text','Start time (s):');
            app.StartEdit = uieditfield(gl,'numeric');

            % Row 4: Jitter A
            uilabel(gl,'Text','Start jitter A (s):');
            app.JitterAEdit = uieditfield(gl,'numeric');

            % Row 5: Jitter B
            uilabel(gl,'Text','Start jitter B (s):');
            app.JitterBEdit = uieditfield(gl,'numeric');

            % Row 6: Max duration
            uilabel(gl,'Text','Max duration (s):');
            app.MaxDurEdit = uieditfield(gl,'numeric');

            % Row 7: Identifier
            uilabel(gl,'Text','Identifier:');
            app.IdentifierEdit = uieditfield(gl,'text','Placeholder','e.g., A1');

            % Row 8: Buttons (place in a sub-grid, right aligned)
            btnGrid = uigridlayout(gl,[1 3]);
            btnGrid.ColumnWidth = {'1x',90,90};
            btnGrid.RowHeight = {34};
            btnGrid.Padding = [0 0 0 0];
            btnGrid.ColumnSpacing = 8;
            btnGrid.Layout.Column = [1 2];

            app.OKButton = uibutton(btnGrid,'Text','OK','ButtonPushedFcn',@(~,~)app.ok_());
            app.OKButton.Layout.Column = 2;
            app.CancelButton = uibutton(btnGrid,'Text','Cancel','ButtonPushedFcn',@(~,~)delete(app.UIFigure));
            app.CancelButton.Layout.Column = 3;

        end

        function load_(app)
            app.KindLabel.Text = "Kind: " + upper(string(app.ev.kind));
            if strlength(app.ev.modality)==0
                app.ev.modality = "auditory";
            end
            app.TypeDropDown.Value = char(app.ev.modality);
            app.StartEdit.Value = app.ev.tStart;
            app.JitterAEdit.Value = app.ev.jitterA;
            app.JitterBEdit.Value = app.ev.jitterB;
            if ~isfinite(app.ev.maxDur) || app.ev.maxDur<=0, app.ev.maxDur = 0.3; end
            app.MaxDurEdit.Value = app.ev.maxDur;
            app.IdentifierEdit.Value = char(app.ev.identifier);
        end

        function ok_(app)
            app.ev.modality = string(app.TypeDropDown.Value);
            app.ev.tStart = app.StartEdit.Value;
            app.ev.jitterA = app.JitterAEdit.Value;
            app.ev.jitterB = app.JitterBEdit.Value;
            app.ev.maxDur = app.MaxDurEdit.Value;
            app.ev.identifier = string(app.IdentifierEdit.Value);

            app.onCommit(app.ev);
            delete(app.UIFigure);
        end
    end
end
