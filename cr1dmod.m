function varargout = cr1dmod(varargin)

% CR1DMOD is the main function in a 1D forward modelling package which has
% the capability of modelling Complex Resistivity effects.
% A call to CR1DMOD will open the main gui interface, from which layered
% earth models can be created and measurement configurations defined.
%
% The program is written for and tested in Matlab 6.5 R13.
%
% The program is described in:
% Ingeman-Nielsen, T. and Baumgartner, F. (2005): CR1Dmod: A Matlab program
% to model 1D Complex Resistivity effects in electrical and electromagnetic
% surveys, submitted to Computers & Geosciences.
%
% The CR1DMOD package includes the files:
% cr1dmod.m:          This file
% cr1dmod.fig:        Gui layout of the main window
% topview.fig:        Gui layout of the topview window, which allows the
%                       user to place electrodes and wires arbitrarily on
%                       the surface of the half-space.
% topview.m:          Functions relating to the topview GUI
% compute.fig:        Gui layout of the compute window, from which
%                       calculation speciffic parameters are defined and the
%                       actual computation started.
% compute.m:          Functions relating to the compute GUI
% dcgsafwd.m:         Forward modelling code for the DC response of a
%                       general surface electrode array
% emgsafwd.m:         Forward modelling code for the EM response of a
%                       general surface electrode array
% temfwd.m:           Forward modelling code for the frequency and transient
%                       response of the central loop configuration
% fdemfwd.m:          Forward modelling code for the frequency response of a
%                       horizontal coplanar loop configuration
% NJCST.m:            Routine to perform numerical hankel and harmonic
%                       transforms
% zeros_J.mat:        Precalculated values of the zeros of the bessel
%                       functions used in the NJCST hankel transform
% FJCST.m:            Routine to perform hankel and harmonic transforms
%                       using the digital filter method
% FCST.m:             Similar to FJCST but calculates only harmonic
%                       transforms
% filters.mat:        Filter coefficients needed in FJCST and FCST
% Z_CR.m:             Function to calculate the resistivity dispersion based
%                       on the cole-cole model
% neg_loglog.m:       Function to create a loglog plot where positive data
%                       values plot in blue, and negative data values in red.
%
% Written by:
% Thomas Ingeman-Nielsen
% The Arctic Technology Center, BYG
% Technical University of Denmark
% Email: tin@byg.dtu.dk


% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @cr1dmod_OpeningFcn, ...
    'gui_OutputFcn',  @cr1dmod_OutputFcn, ...
    'gui_LayoutFcn',  [] , ...
    'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

% --------------------------------------------------------------------
% --- Executes just before cr1dmod is made visible.
function cr1dmod_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to cr1dmod (see VARARGIN)

% Choose default command line output for cr1dmod
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

if nargin > 3
    for k = 1:nargin-3
        if ischar(varargin{k}) && strcmpi(varargin{k},'debug')
            setappdata(0, 'debug', 1);  % 1: go through debug code
            set(handles.Keyboard_menu, 'Visible', 'on');
            disp('The code will display debug information!');
            break;
        end
    end
end     

if ~isappdata(0,'debug') || ~getappdata(0,'debug') 
    set(handles.Keyboard_menu, 'Visible', 'off');
end

if strcmp(get(hObject,'Visible'),'off')
    testVar = 1;
    if exist('testVar', 'var')
        % Executes when the code is running in the matlab environment
        setappdata(0, 'compiled', 0);  % 1: bypass non-compilable code
        handles.mfilePath = fileparts(mfilename('fullpath'));
        I = strmatch(handles.mfilePath,path);
        if isempty(I)
            addpath(handles.mfilePath,'-begin');
            handles.mfilePathRemove = 1;
        else
            handles.mfilePathRemove = 0;
        end
    else
        % Executes when the code is compiled        
        setappdata(0, 'compiled', 1);  % 1: bypass non-compilable code
        handles.mfilePathRemove = 0;
    end
    
    axes(handles.axes1);
    
    list = {'Dipole-Dipole',...
            ...%'*Capacitance*',...
            'Wenner',...
            'Schlumberger',...
            'General Surface Array',...
            ...%'*GSA capacitance*',...
            'TEM Central Loop',...
            'HCP FDEM (HLEM)'};
    
    set(handles.Config_popup,'string',list);
    
    handles.config.type = 'Dipole-Dipole';
    handles.config.Aspac = 100;
    handles.config.Nspac = 1;
    handles.config.Rspac = 100;
    handles.config.OA = 100;
    handles.config.OM = 1;
    handles.config.Cwire = [];
    handles.config.Pwire = [];
    handles.config.TxS = 40;
    handles.config.RxA = 100;
    
    % Update handles structure
    guidata(hObject, handles);
    
    handles.layers(1).depth_to_top = 0;
    handles.layers(1).thickness = inf;
    handles.layers(1).rho = 100;
    handles.layers(1).m = 0;
    handles.layers(1).tau = 0;
    handles.layers(1).c = 0;
    handles.layers(1).mu = '0';   % NB this is the magnetic susceptibility!
    handles.layers(1).eps_r = 1;
    
    handles.model = [];
    
    set(handles.axes1,'ylim',[-50 20]);
    hold on;
    handles.surface = plot(get(handles.axes1,'xlim'),[0 0],'-k','linewidth',2);
    
    handles = update_config(handles);
    handles = update_model(handles);
    update_layer_param(handles);
    
    % Update handles structure
    guidata(hObject, handles);
    
end

% UIWAIT makes cr1dmod wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --------------------------------------------------------------------
% --- Outputs from this function are returned to the command line.
function varargout = cr1dmod_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% *****************************************************************
% * Callback functions related to model plot                      *
% *****************************************************************

% --------------------------------------------------------------------
% --- Executes on button press in axes1.
function axes1_Callback(hObject, eventdata, handles)

loc = get(hObject, 'currentpoint');
depth = round(loc(2,2)*10)/10;
if depth<0
    % find all interfaces above the one to be made
    index = find([handles.layers.depth_to_top]<-depth);    
    
    layer_num = index(end); 
    handles.layers(layer_num+1:end+1) = handles.layers(layer_num:end);
    if layer_num == 1
        handles.layers(layer_num).thickness = -depth;
    else
        handles.layers(layer_num).thickness =                           ...
            -depth-handles.layers(layer_num).depth_to_top;
    end
    handles.layers(layer_num+1).thickness =                             ...
        handles.layers(layer_num+1).thickness -                         ...
        handles.layers(layer_num).thickness;     
    handles.layers(layer_num+1).depth_to_top = -depth;
    handles.layers(layer_num).interface_handle = [];
    % ^ otherwise it points to the interface of layer_num+1!
    handles.layers(layer_num).prop_lab_handle = [];
    handles.layers(layer_num).label_handle = [];
    
    handles = update_model(handles);
    update_layer_param(handles);
    
    % Update handles structure
    guidata(hObject, handles);
    
    set(gcbf,'WindowButtonUpFcn',@interface_ButtonUp_Callback);
    set(gcbf,'WindowButtonMotionFcn',{@interface_Move_Callback, layer_num+1}); 
end


% --------------------------------------------------------------------
% --- Executes on button press on an interface.
function interface_ButtonDown_Callback(hObject, eventdata)

handles = guidata(hObject);
interface = find([handles.layers.interface_handle]==hObject)+1;
click_type = get(gcbf,'SelectionType');
switch click_type
    case{'normal'}   % left click
        set(gcbf,'WindowButtonUpFcn',@interface_ButtonUp_Callback);
        set(gcbf,'WindowButtonMotionFcn',                               ...
            {@interface_Move_Callback, interface});        
    case{'extend'}   % Shift - left
    case{'alt'}      % Ctrl - left    
    case{'open'}     % Double click
end


% --------------------------------------------------------------------
% --- Executes on button release on an interface.
function interface_ButtonUp_Callback(hObject, eventdata)

set(gcbf,'WindowButtonMotionFcn','');
handles = guidata(hObject);
%ylimmits = ylim;

if length(handles.layers) > 1
    set(handles.axes1, 'ylim', ([-1 2/5] * (9/7 *                       ...
        handles.layers(end).depth_to_top)));
end

if strcmp(handles.config.type,'TEM Central Loop')
    yscale = diff(get(handles.axes1,'ylim'));
    t = sin(0:pi/100:pi).*yscale./70;
    set(handles.config.plot_handle(1),'ydata',t.*4);
    set(handles.config.plot_handle(2),'ydata',t.*1);
elseif strcmp(handles.config.type,'HCP FDEM (HLEM)')
    yscale = diff(get(handles.axes1,'ylim'));
    t = sin(0:pi/100:2.*pi)'.*yscale./70;
    set(handles.config.plot_handle(1:2), 'ydata', t, 'linewidth',       ...
        2, 'color', 'b');
    set(handles.config.plot_handle(3:4), 'ydata',                       ...
        [-yscale +yscale].*1.5./70,'linewidth',2,'color','b');
end

handles = update_model(handles);



% --------------------------------------------------------------------
% --- Executes on mouse movement with button pressed on an interface.
function interface_Move_Callback(hObject, eventdata, interface)

handles = guidata(hObject);

CurrentPoint = mean(get(gca,'CurrentPoint'));

layer_num = interface-1;

ylimmits = ylim;
if -CurrentPoint(2)<=handles.layers(layer_num).depth_to_top
    CurrentPoint(2) = -handles.layers(layer_num).depth_to_top;
elseif -CurrentPoint(2) >= handles.layers(layer_num+1).depth_to_top +   ...
        handles.layers(layer_num+1).thickness
    CurrentPoint(2) = -handles.layers(layer_num+1).depth_to_top -       ...
        handles.layers(layer_num+1).thickness;
elseif CurrentPoint(2)<ylimmits(1)
    temppoint = CurrentPoint;
    if isfield(handles,'lastpoint')
        if handles.lastpoint(2)>CurrentPoint(2)
            set(handles.axes1,'ylim',(ylimmits-[1 -2/5]));
            CurrentPoint(2) = ylimmits(1)-1;
        else 
            CurrentPoint(2) = ylimmits(1);
        end    
    else
        set(handles.axes1,'ylim',(ylimmits-[1 -2/5]));
        CurrentPoint(2) = ylimmits(1)-1;
    end
    handles.lastpoint = temppoint;
end

handles.layers(layer_num).thickness = round((-CurrentPoint(2) -         ...
    handles.layers(layer_num).depth_to_top) * 10) / 10;
handles.layers(layer_num+1).thickness =                                 ...
    round((handles.layers(layer_num+1).thickness -                      ...
    (-CurrentPoint(2)-handles.layers(layer_num+1).depth_to_top))*10)/10;
handles.layers(layer_num+1).depth_to_top = round(-CurrentPoint(2)*10)/10;

if strcmp(handles.config.type,'TEM Central Loop')
    yscale = diff(get(handles.axes1,'ylim'));
    t = sin(0:pi/100:pi).*yscale./70;
    set(handles.config.plot_handle(1),'ydata',t.*4);
    set(handles.config.plot_handle(2),'ydata',t.*1);
elseif strcmp(handles.config.type,'HCP FDEM (HLEM)')
    yscale = diff(get(handles.axes1,'ylim'));
    t = sin(0:pi/100:2.*pi)'.*yscale./70;
    set(handles.config.plot_handle(1), 'ydata', t, 'linewidth', 2,      ...
        'color', 'b');
    set(handles.config.plot_handle(2), 'ydata', t, 'linewidth', 2,      ...
        'color', 'b');
    set(handles.config.plot_handle(3), 'ydata',                         ...
        [-yscale +yscale].*1.5./70, 'linewidth', 2, 'color', 'b');
    set(handles.config.plot_handle(4), 'ydata',                         ...
        [-yscale +yscale].*1.5./70, 'linewidth', 2, 'color', 'b');
end

handles = update_model(handles);

update_layer_param(handles);

guidata(hObject, handles);


% *****************************************************************
% * Callback functions related to model input section             *
% *****************************************************************

% --------------------------------------------------------------------
% --- Executes on selection change in Layer_popup.
function Layer_popup_Callback(hObject, eventdata, handles)

update_layer_param(handles);


% --------------------------------------------------------------------
function h_edit_Callback(hObject, eventdata, handles)

layer_index = get(handles.Layer_popup,'Value');
handles.layers(layer_index).thickness = str2num(get(hObject,'String'));

if handles.layers(layer_index).thickness > 0
    
    handles = update_model(handles);
    
    %ylimmits = ylim;
    set(handles.axes1,'ylim',([-1 2/5] * (9/7 *                         ...
        handles.layers(end).depth_to_top)));
        
    if strcmp(handles.config.type,'TEM Central Loop')
        yscale = diff(get(handles.axes1,'ylim'));
        t = sin(0:pi/100:pi).*yscale./70;
        set(handles.config.plot_handle(1),'ydata',t.*4);
        set(handles.config.plot_handle(2),'ydata',t.*1);
    end
    guidata(hObject, handles);
else
    delete_button_Callback(hObject, [], handles);
end % if

handles = guidata(hObject);
handles = update_model(handles);
guidata(hObject, handles);

% --------------------------------------------------------------------
function DC_res_edit_Callback(hObject, eventdata, handles)

layer_index = get(handles.Layer_popup,'Value');
handles.layers(layer_index).rho = str2num(get(hObject,'String'));

handles = update_model(handles);

guidata(hObject, handles);


% --------------------------------------------------------------------
function m_edit_Callback(hObject, eventdata, handles)

layer_index = get(handles.Layer_popup,'Value');
handles.layers(layer_index).m = str2num(get(hObject,'String'));

handles = update_model(handles);

guidata(hObject, handles);


% --------------------------------------------------------------------
function Tau_edit_Callback(hObject, eventdata, handles)

layer_index = get(handles.Layer_popup,'Value');
handles.layers(layer_index).tau = str2num(get(hObject,'String'));

handles = update_model(handles);

guidata(hObject, handles);


% --------------------------------------------------------------------
function c_edit_Callback(hObject, eventdata, handles)

layer_index = get(handles.Layer_popup,'Value');
handles.layers(layer_index).c = str2num(get(hObject,'String'));

handles = update_model(handles);

guidata(hObject, handles);


% --------------------------------------------------------------------
function Eps_r_edit_Callback(hObject, eventdata, handles)

layer_index = get(handles.Layer_popup,'Value');
handles.layers(layer_index).eps_r = str2num(get(hObject,'String'));

handles = update_model(handles);

guidata(hObject, handles);


% --------------------------------------------------------------------
function Mu_edit_Callback(hObject, eventdata, handles)

layer_index = get(handles.Layer_popup,'Value');

% New code to accomodate test for mu==1;
str = get(hObject,'String');
num = str2num(str);

if ~isempty(num)
    handles.layers(layer_index).mu = str;
end
set(handles.Mu_edit, 'string', handles.layers(layer_index).mu);

guidata(hObject, handles);


% *****************************************************************
% * Callback functions related to model input section             *
% *****************************************************************

% --------------------------------------------------------------------
% --- function to update model plot.
function handles = update_model(handles)

layers = handles.layers;

ylimmits = ylim;
xlimmits = xlim;

set(handles.surface,'xdata',xlimmits);

for k=1:length(layers)-1
    % recalculate depths 
    layers(k+1).depth_to_top = layers(k).depth_to_top +                 ...
        layers(k).thickness;
    
    % Update interface locations
    if isfield(layers(k),'interface_handle') &&                         ...
        ~isempty(layers(k).interface_handle) &&                         ...
        ishandle(layers(k).interface_handle)
        set(layers(k).interface_handle,'ydata',                         ...
            [-1 -1] * layers(k+1).depth_to_top, 'xdata',xlimmits);
    elseif ~isinf(layers(k).thickness)
        % plot interface
        layers(k).interface_handle = plot(get(handles.axes1,'xlim'),    ...
            [-1 -1].*(layers(k).depth_to_top+layers(k).thickness),'-k');  
        set(layers(k).interface_handle,'ButtonDownFcn',                 ...
            @interface_ButtonDown_Callback);
    end
    
    % Update labels of layers
    % Thickness label 
    if layers(k).m ~= 0 && layers(k).tau ~= 0 && layers(k).c ~= 0
        tmpStr = '^{C-C}';
    else
        tmpStr = '';
    end % if
    
    if isfield(layers(k),'prop_lab_handle') &&                          ...
            ~isempty(layers(k).prop_lab_handle) &&                      ...
            ishandle(layers(k).prop_lab_handle)
        set(layers(k).prop_lab_handle,'String',                         ...
            ['h = ' sprintf('%.1f m', layers(k).thickness)              ...
                '    \rho_{DC}' tmpStr ' = ' sprintf('%.1f \\Omegam',   ...
                layers(k).rho)],                                        ...
            'Position', [mean(get(handles.axes1,'xlim')),               ...
                -mean([layers(k).depth_to_top                           ...
                    (layers(k).depth_to_top+layers(k).thickness)])],    ...
            'ButtonDownFcn', {@layer_label_Callback, k});    
    else
        layers(k).prop_lab_handle = text(mean(get(handles.axes1,        ...
            'xlim')), -mean([layers(k).depth_to_top                     ...
                (layers(k).depth_to_top+layers(k).thickness)]),         ...
            ['h = ' sprintf('%.1f m', layers(k).thickness)              ...
                '    \rho_{DC}' tmpStr ' = ' sprintf('%.1f \\Omegam',   ...
                layers(k).rho)],                                        ...
            'VerticalAlignment',   'middle',                            ...
            'HorizontalAlignment', 'center',                            ...
            'FontSize',             8,                                  ...
            'ButtonDownFcn',        {@layer_label_Callback, k});    
    end
    
    if isfield(layers(k),'label_handle') &&                             ...
           ~isempty(layers(k).label_handle) &&                          ...
           ishandle(layers(k).label_handle)
        set(layers(k).label_handle,'Position',...
            [0.05*(xlimmits(2)-xlimmits(1))+xlimmits(1),                ...
                ylimmits(1)/120-layers(k).depth_to_top],                ...
            'String',['Layer ' num2str(k)],                             ...
            'ButtonDownFcn', {@layer_label_Callback, k});
    else
        layers(k).label_handle = text(0.05*(xlimmits(2)-xlimmits(1))+   ...
            xlimmits(1), ylimmits(1)/120-layers(k).depth_to_top,        ...
            ['Layer ' num2str(k)],                                      ...
            'VerticalAlignment',   'top',                               ...
            'HorizontalAlignment', 'left',                              ...
            'FontSize',             8,                                  ...
            'ButtonDownFcn',        {@layer_label_Callback, k});    
    end
end

if isfield(layers(end),'label_handle') &&                               ...
       ~isempty(layers(end).label_handle) &&                              ... 
       ishandle(layers(end).label_handle)
    set(layers(end).label_handle,'Position',                            ...
        [0.05*(xlimmits(2)-xlimmits(1))+xlimmits(1),                    ...
            ylimmits(1)/120-layers(end).depth_to_top],                  ...
        'ButtonDownFcn', {@layer_label_Callback, length(layers)});
else
    layers(end).label_handle = text(0.05*(xlimmits(2)-xlimmits(1))+     ...
        xlimmits(1), ylimmits(1)/120-layers(end).depth_to_top,          ...
        'Lower half-space',                                             ...
        'VerticalAlignment',   'top',                                   ...
        'HorizontalAlignment', 'left',                                  ...
        'FontSize',             8,                                      ...
        'ButtonDownFcn',        {@layer_label_Callback, length(layers)});
end


if layers(end).m ~= 0 && layers(end).tau ~= 0 && layers(end).c ~= 0
    tmpStr = '^{C-C}';
else
    tmpStr = '';
end % if
if isfield(layers(end),'prop_lab_handle') &&                            ...
        ~isempty(layers(end).prop_lab_handle)                           ...
        ishandle(layers(end).prop_lab_handle)
    set(layers(end).prop_lab_handle,'String',                           ...
        ['\rho_{DC}' tmpStr ' = ' sprintf('%.1f \\Omegam',              ...
            layers(end).rho)],                                          ...
        'Position', [mean(get(handles.axes1,'xlim')),                   ...
            mean([-layers(end).depth_to_top ylimmits(1)])],             ...
        'ButtonDownFcn', {@layer_label_Callback, length(layers)});
else
    layers(end).prop_lab_handle = text(mean(get(handles.axes1,          ...
        'xlim')), mean([-layers(end).depth_to_top ylimmits(1)]),        ...
        ['\rho_{DC}' tmpStr ' = ' sprintf('%.1f \\Omegam',              ...
            layers(k).rho)],                                            ...
        'VerticalAlignment',   'middle',                                ...
        'HorizontalAlignment', 'center',                                ...
        'FontSize',             8,                                      ...
        'ButtonDownFcn',        {@layer_label_Callback, length(layers)});
end

handles.layers = layers;


% --------------------------------------------------------------------
% --- function to update layer parameters input section.
function update_layer_param(handles)

layer_index = get(handles.Layer_popup,'Value');
%contents = get(handles.Layer_popup,'String');

for k = 1:length(handles.layers)-1
    pop_string{k} = ['Layer ' num2str(k)];
end
pop_string{length(handles.layers)} = 'Lower half-space';
    
set(handles.Layer_popup,'String',pop_string); 

if strcmp(pop_string{layer_index},'Lower half-space')
    set(handles.h_edit,'Enable','off');
else
    set(handles.h_edit,'Enable','on');
end

set(handles.h_edit,'String',num2str(handles.layers(layer_index).thickness));
set(handles.DC_res_edit,'String',num2str(handles.layers(layer_index).rho));
set(handles.m_edit,'String',num2str(handles.layers(layer_index).m));
set(handles.Tau_edit,'String',num2str(handles.layers(layer_index).tau));
set(handles.c_edit,'String',num2str(handles.layers(layer_index).c));
set(handles.Mu_edit,'String',handles.layers(layer_index).mu);
%set(handles.Mu_edit,'String',num2str(handles.layers(layer_index).mu));
set(handles.Eps_r_edit,'String',num2str(handles.layers(layer_index).eps_r));

% print label of selected layer in bold
set(handles.layers(layer_index).label_handle,'FontWeight','bold');
set([handles.layers(find((1:length(handles.layers))~=                   ...
        layer_index)).label_handle],'FontWeight','normal');


% --------------------------------------------------------------------
% --- function to update configuration input section and plot.
function handles = update_config(handles)

switch handles.config.type
    case {'Dipole-Dipole','*Capacitance*'}
        set(handles.topview_button,'enable','on');
        set([handles.Aspac_edit handles.Aspactxt],'visible','on');
        set([handles.Nspac_edit handles.Nspactxt],'visible','on');
        set([handles.OA_edit handles.OA_txt],'visible','off');
        set([handles.OM_edit handles.OM_txt],'visible','off');
        set([handles.Tx_side_edit handles.Tx_side_txt],'visible','off');
        set([handles.Rx_area_edit handles.Rx_area_txt],'visible','off');
        set([handles.Rspac_edit handles.Rspac_txt], 'visible', 'off');
        
        if length(handles.config.Aspac)>1
            tmpstr =  ['[' sprintf('%i ',handles.config.Aspac)];
            tmpstr(end) = ']';
            set(handles.Aspac_edit,'String',tmpstr,'visible','on');
        else
            set(handles.Aspac_edit, 'String',                           ...
                num2str(handles.config.Aspac),'visible','on');
        end
        if length(handles.config.Nspac)>1
            tmpstr =  ['[' sprintf('%i ',handles.config.Nspac)];
            tmpstr(end) = ']';
            set(handles.Nspac_edit,'String',tmpstr,'visible','on');
        else
            set(handles.Nspac_edit, 'String',                           ...
                num2str(handles.config.Nspac),'visible','on');
        end
        
        % transmitter dipole            C1  a  C2     P1  a  P2
        % transmitter dipole            o------o      o------o            
        % receiver dipole                 Tx     n*a    Rx
        
        handles.config.C1 = [-handles.config.Aspac(1)-...
                0.5*handles.config.Aspac(1)*handles.config.Nspac(1) 0 0];  
        handles.config.C2 = [handles.config.C1(1)+...
                handles.config.Aspac(1) 0 0];                              
        handles.config.P1 = [handles.config.C2(1)+...                      
                handles.config.Nspac(1)*handles.config.Aspac(1) 0 0];   
        handles.config.P2 = [handles.config.P1(1)+...                      
                handles.config.Aspac(1) 0 0];     
        handles.config.Cwire = [];
        handles.config.Pwire = [];

    case {'General Surface Array', '*GSA capacitance*'};
        set(handles.topview_button,'enable','on');
        set([handles.Aspac_edit handles.Aspactxt],'visible','off');
        set([handles.Nspac_edit handles.Nspactxt],'visible','off');
        set([handles.OA_edit handles.OA_txt],'visible','off');
        set([handles.OM_edit handles.OM_txt],'visible','off');
        set([handles.Tx_side_edit handles.Tx_side_txt],'visible','off');
        set([handles.Rx_area_edit handles.Rx_area_txt],'visible','off');
        set([handles.Rspac_edit handles.Rspac_txt], 'visible', 'off');
    case {'Wenner'}
        set(handles.topview_button,'enable','on');        
        set([handles.Aspac_edit handles.Aspactxt],'visible','on');
        set([handles.Nspac_edit handles.Nspactxt],'visible','off');
        set([handles.OA_edit handles.OA_txt],'visible','off');
        set([handles.OM_edit handles.OM_txt],'visible','off');
        set([handles.Tx_side_edit handles.Tx_side_txt],'visible','off');
        set([handles.Rx_area_edit handles.Rx_area_txt],'visible','off');
        set([handles.Rspac_edit handles.Rspac_txt], 'visible', 'off');
        
        if length(handles.config.Aspac)>1
            tmpstr =  ['[' sprintf('%i ',handles.config.Aspac)];
            tmpstr(end) = ']';
            set(handles.Aspac_edit,'String',tmpstr,'visible','on');
        else
            set(handles.Aspac_edit, 'String',                           ...
                num2str(handles.config.Aspac),'visible','on');
        end
        
        % transmitter electrode   C1     P1     P2     C2
        % transmitter electrode   o------o------o------o    
        % receiver electrode         a       a      a      
        
        handles.config.C1 = [-1.5.*handles.config.Aspac(1) 0 0];  
        handles.config.C2 = [1.5.*handles.config.Aspac(1) 0 0];   
        handles.config.P1 = [-0.5.*handles.config.Aspac(1) 0 0]; 
        handles.config.P2 = [0.5.*handles.config.Aspac(1) 0 0];   
        handles.config.Cwire = [];
        handles.config.Pwire = [];

    case {'Schlumberger'}
        set(handles.topview_button,'enable','on');        
        set([handles.Aspac_edit handles.Aspactxt],'visible','off');
        set([handles.Nspac_edit handles.Nspactxt],'visible','off');
        set([handles.Tx_side_edit handles.Tx_side_txt],'visible','off');
        set([handles.Rx_area_edit handles.Rx_area_txt],'visible','off');
        set([handles.OA_edit handles.OA_txt],'visible','on');
        set([handles.OM_edit handles.OM_txt],'visible','on');
        set([handles.Rspac_edit handles.Rspac_txt], 'visible', 'off');
        
        if length(handles.config.OA)>1
            tmpstr =  ['[' sprintf('%i ',handles.config.OA)];
            tmpstr(end) = ']';
            set(handles.OA_edit,'String',tmpstr,'visible','on');
        else
            set(handles.OA_edit,'String',num2str(handles.config.OA),    ...
                'visible','on');
        end
        if length(handles.config.OM)>1
            tmpstr =  ['[' sprintf('%i ',handles.config.OM)];
            tmpstr(end) = ']';
            set(handles.OM_edit,'String',tmpstr,'visible','on');
        else
            set(handles.OM_edit,'String',num2str(handles.config.OM),    ...
                'visible','on');
        end
        
        % transmitter electrode   C1       P1  P2       C2
        % transmitter electrode   o--------o---o--------o    
        % receiver electrode      |    OA    |        
        % receiver electrode               | | OM 
        
        handles.config.C1 = [-handles.config.OA(1) 0 0];  
        handles.config.C2 = [handles.config.OA(1) 0 0];   
        handles.config.P1 = [-handles.config.OM(1) 0 0];  
        handles.config.P2 = [handles.config.OM(1) 0 0];   
        handles.config.Cwire = [];
        handles.config.Pwire = [];
        
    case {'TEM Central Loop'}
        set(handles.topview_button,'enable','off');        
        set([handles.Aspac_edit handles.Aspactxt],'visible','off');
        set([handles.Nspac_edit handles.Nspactxt],'visible','off');
        set([handles.OA_edit handles.OA_txt],'visible','off');
        set([handles.OM_edit handles.OM_txt],'visible','off');
        set([handles.Tx_side_edit handles.Tx_side_txt],'visible','on');
        set([handles.Rx_area_edit handles.Rx_area_txt],'visible','on');
        set([handles.Rspac_edit handles.Rspac_txt], 'visible', 'off');
        
        t = (0:pi/100:pi)';
        if isfield(handles.config,'plot_handle') &&                      ...
                any(ishandle(handles.config.plot_handle))
            delete(handles.config.plot_handle);
            handles.config.plot_handle=[];
        end
        yscale = diff(get(handles.axes1,'ylim'));
        handles.config.plot_handle(1) = line(cos(t)*100,                ...
            sin(t).*4.*yscale./70,'linewidth',2,'color','b');
        handles.config.plot_handle(2) = line(cos(t)*25,                 ...
            sin(t).*1.*yscale./70,'linewidth',2,'color','b');
        set(handles.axes1,'xlim',[-120 120]);
    case {'HCP FDEM (HLEM)'}
        set(handles.topview_button,'enable','off');        
        set([handles.Aspac_edit handles.Aspactxt],'visible','off');
        set([handles.Nspac_edit handles.Nspactxt],'visible','off');
        set([handles.OA_edit handles.OA_txt],'visible','off');
        set([handles.OM_edit handles.OM_txt],'visible','off');
        set([handles.Tx_side_edit handles.Tx_side_txt],'visible','off');
        set([handles.Rx_area_edit handles.Rx_area_txt],'visible','off');
        set([handles.Rspac_edit handles.Rspac_txt],'visible','on');
        
        if isfield(handles.config,'plot_handle') &&                      ...
                any(ishandle(handles.config.plot_handle))
            delete(handles.config.plot_handle);
            handles.config.plot_handle=[];
        end
        yscale = diff(get(handles.axes1,'ylim'));
        t = (0:pi/100:2.*pi)';
        handles.config.plot_handle(1) = line(cos(t)*10-50,              ...
            sin(t).*yscale./70,'linewidth',2,'color','b');
        handles.config.plot_handle(2) = line(cos(t)*10+50,              ...
            sin(t).*yscale./70,'linewidth',2,'color','b');
        handles.config.plot_handle(3) = line(-[50 50],                  ...
            [-yscale +yscale].*1.5./70,'linewidth',2,'color','b');
        handles.config.plot_handle(4) = line(+[50 50],                  ...
            [-yscale +yscale].*1.5./70,'linewidth',2,'color','b');
        set(handles.axes1,'xlim',[-120 120]);
end

switch handles.config.type
    case {'Dipole-Dipole',                                              ...
            '*Capacitance*',                                            ...
            'General Surface Array',                                    ...
            '*GSA capacitance*',                                        ...
            'Wenner',                                                   ... 
            'Schlumberger'}
        if isfield(handles.config,'plot_handle') &&                      ...
                any(ishandle(handles.config.plot_handle))
            delete(handles.config.plot_handle);
            handles.config.plot_handle=[];
        end
        handles.config.plot_handle(1) = line(handles.config.C1(1),0,    ...
            'marker','v');
        handles.config.plot_handle(2) = line(handles.config.C2(1),0,    ...
            'marker','v');
        handles.config.plot_handle(3) = line(handles.config.P1(1),0,    ...
            'marker','v');
        handles.config.plot_handle(4) = line(handles.config.P2(1),0,    ...
            'marker','v');
        xcoords = [min([handles.config.C1 handles.config.C2             ...
                    handles.config.P1 handles.config.P2])               ...
                max([handles.config.C1 handles.config.C2                ...
                    handles.config.P1 handles.config.P2])];
        set(handles.axes1,'xlim',([xcoords(1)-diff(xcoords)*0.15        ...
                xcoords(2)+diff(xcoords)*0.15]));
end

handles = update_model(handles);


% --------------------------------------------------------------------
% --- Executes on selection change in Config_popup.
function Config_popup_Callback(hObject, eventdata, handles)

list = get(handles.Config_popup,'string');
handles.config.type = list{get(handles.Config_popup,'Value')};
handles = update_config(handles);
guidata(hObject,handles);

if isfield(handles, 'compute_win') && ishandle(handles.compute_win)
    compute('setup_gui',handles.compute_win, [],                       ...
        guidata(handles.compute_win), 'Default');
end


% --------------------------------------------------------------------
function Aspac_edit_Callback(hObject, eventdata, handles)

[num,isOK] = str2num(get(handles.Aspac_edit,'String'));
if isOK && all(isfinite(num))
    handles.config.Aspac = num;
else
    set(handles.Aspac_edit,'String',num2str(handles.config.Aspac));
end

handles.config.Aspac = str2num(get(handles.Aspac_edit,'String'));
handles = update_config(handles);
handles = update_model(handles);
guidata(hObject, handles);


% --------------------------------------------------------------------
function Nspac_edit_Callback(hObject, eventdata, handles)

[num,isOK] = str2num(get(handles.Nspac_edit,'String'));
if isOK && all(isfinite(num))
    handles.config.Nspac = num;
else
    set(handles.Nspac_edit,'String',num2str(handles.config.Nspac ));
end

handles = update_config(handles);
handles = update_model(handles);
guidata(hObject, handles);


% --------------------------------------------------------------------
function OA_edit_Callback(hObject, eventdata, handles)

[num,isOK] = str2num(get(handles.OA_edit,'String'));
if isOK && all(isfinite(num))
    handles.config.OA = num;
else
    set(handles.OA_edit,'String',num2str(handles.config.OA ));
end
    
handles = update_config(handles);
handles = update_model(handles);
guidata(hObject, handles);


% --------------------------------------------------------------------
function OM_edit_Callback(hObject, eventdata, handles)

[num,isOK] = str2num(get(handles.OM_edit,'String'));
if isOK && all(isfinite(num))
    handles.config.OM = num;
else
    set(handles.OM_edit,'String',num2str(handles.config.OM ));
end

handles = update_config(handles);
handles = update_model(handles);
guidata(hObject, handles);


% --------------------------------------------------------------------
function Rspac_edit_Callback(hObject, eventdata, handles)

[num,isOK] = str2num(get(handles.Rspac_edit,'String'));
if isOK && all(isfinite(num))
    handles.config.Rspac = num;
else
    set(handles.Rspac_edit,'String',num2str(handles.config.Rspac));
end

handles = update_config(handles);
handles = update_model(handles);
guidata(hObject, handles);


% --------------------------------------------------------------------
function File_Callback(hObject, eventdata, handles)
% hObject    handle to File (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function Open_Callback(hObject, eventdata, handles)
% hObject    handle to Open (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

[filename, pathname] = uigetfile( ...
    {'*.mat', 'Model file (*.mat)';...
        '*.*',                   'All Files (*.*)'}, ...
    'Load model:');

if ~isequal(filename,0) && ~isequal(pathname,0)
    input = load([pathname filesep filename]);
    if ~isstruct(input) || (~isfield(input, 'model') && ~isfield(input, 'batchlist'))
        disp('cr1dmod.m:Open_Callback:NoModelInFile  No model data found in file!');
        error('cr1dmod.m:Open_Callback:NoModelInFile',                  ...
            'No model data found in file!');
    end
    
    if isfield(input, 'batchlist')
        input.model = rmfield(input.batchlist(1), 'cparams');  
        % Here we should allow for user choice of which model to use, and
        % to include also the calculation parameters.
    end
    
    if isfield(input, 'model') && isstruct(input.model) &&                      ...
            isfield(input.model, 'layers') && isfield(input.model, 'config')

        if isfield(input.model.config, 'plot_handle') 
            input.model.config = rmfield(input.model.config,{'plot_handle'});
        end
        if isfield(input.model.layers, 'label_handle') 
            input.model.layers = rmfield(input.model.layers,{'label_handle'});
        end
        if isfield(input.model.layers,'interface_handle')
            input.model.layers = rmfield(input.model.layers,{'interface_handle',            ...
                    'prop_lab_handle'});
        end
        
        delete([[handles.layers.label_handle] ...
                [handles.config.plot_handle]]);
        handles.config = [];
        
        handlesToRemove = [];
        
        if length(handles.layers) > 1 
            handlesToRemove = [[handles.layers.interface_handle] ...
                    [handles.layers.prop_lab_handle]];
        else
            handlesToRemove = [handles.layers.prop_lab_handle];    
        end
        
        delete(handlesToRemove);
        handles.layers = [];
        
        handles.config = input.model.config;
        handles.layers = input.model.layers;
        if isfield(input.model,'cparams') && isstruct(input.model.cparams)
            handles.cparams = input.model.cparams;
        end
        
        list = get(handles.Config_popup,'string');
        config_num = find(ismember(list,handles.config.type));
        if ~isempty(config_num);
            set(handles.Config_popup,'value', config_num);
            guidata(hObject,handles);
        else
            disp('Unsupported configuration!')
            return
        end
        
        handles = update_config(handles);
        update_layer_param(handles);
        
        if length(handles.layers) > 1
            set(handles.axes1, 'ylim', ([-1 2/5] * (9/7 *                       ...
                handles.layers(end).depth_to_top)));
        end
        
        handles = update_model(handles);
        
        guidata(hObject,handles);
        
        if isfield(handles, 'compute_win') && ishandle(handles.compute_win)
            if isfield(input, 'model') && isstruct(input.model) &&                      ...
                    isfield(input.model, 'layers') && isfield(input.model, 'config')
                compute('setup_gui',handles.compute_win, [],                       ...
                    guidata(handles.compute_win), 'Default');
                if isfield(input.model,'cparams') && isstruct(input.model.cparams)
                    compute('loadAllSettings',handles.compute_win, [],                       ...
                        guidata(handles.compute_win), input.model.cparams);
                end
            end
        end        
    end
end


% --------------------------------------------------------------------
function Save_Callback(hObject, eventdata, handles)
% hObject    handle to Save (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

[filename, pathname] = uiputfile( ...
    {'*.mat', 'CR1Dmod model file (*.mat)'; ...
        '*.*',                   'All Files (*.*)'}, ...
    'Save model as:');
[tmp, filename,ext] = fileparts(filename);
if isempty(ext), ext = '.mat'; end

model.config = rmfield(handles.config,{'plot_handle'});
model.layers = rmfield(handles.layers,{'label_handle'});
if isfield(model.layers,'interface_handle')
    model.layers = rmfield(model.layers,{'interface_handle',            ...
            'prop_lab_handle'});
end

if isfield(handles,'cparams') && isstruct(handles.cparams)
    model.cparams = handles.cparams;
end

save(fullfile(pathname, [filename ext]), 'model');%,'-MAT');



% --------------------------------------------------------------------
function Compute_Callback(hObject, eventdata, handles)
% hObject    handle to Compute (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function Calculate_Callback(hObject, eventdata, handles)
% hObject    handle to Untitled_2calculate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

compute_win = compute(handles.figure1);
handles = guidata(hObject);
handles.compute_win = compute_win;
guidata(hObject, handles);


% --------------------------------------------------------------------
% --- Executes on button press in topview_button.
function topview_button_Callback(hObject, eventdata, handles)
% hObject    handle to topview_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

config = topview(handles.config);

if isstruct(config)
    handles.config = config;
    set(handles.Config_popup,'value',                                   ...
        find(ismember(get(handles.Config_popup,'string'),               ...
        handles.config.type)));
    handles = update_config(handles);
    guidata(hObject,handles);
end


% --------------------------------------------------------------------
% --- Executes on button press in Add_button.
function add_button_Callback(hObject, eventdata, handles)
% hObject    handle to Add_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles.layers(2:end+1) = handles.layers(1:end);

if length(handles.layers) == 2
   handles.layers(1).thickness = 10;
end

for k = 2:size(get(handles.Layer_popup,'String'),1)
    handles.layers(k).depth_to_top =                                    ...
        handles.layers(k-1).depth_to_top+handles.layers(k-1).thickness;
end

handles.layers(1).interface_handle = [];   
% otherwise it points to the interface of layer 2!
handles.layers(1).prop_lab_handle = [];
handles.layers(1).label_handle = [];

handles = update_model(handles);
guidata(hObject, handles);
update_layer_param(handles);

ylimits = [-1 2/5]*(9/7*handles.layers(end).depth_to_top);
set(handles.axes1,'ylim',ylimits);

if strcmp(handles.config.type,'TEM Central Loop')
    yscale = diff(ylimits);
    t = sin(0:pi/100:pi).*yscale./70;
    set(handles.config.plot_handle(1),'ydata',t.*4);
    set(handles.config.plot_handle(2),'ydata',t.*1);
end

handles = update_model(handles);

guidata(hObject, handles);


% --------------------------------------------------------------------
% --- Executes on button press in delete_button.
function delete_button_Callback(hObject, eventdata, handles)
% hObject    handle to delete_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

layer_index = get(handles.Layer_popup,'Value');

if layer_index ~= size(get(handles.Layer_popup,'String'),1)
%    keyboard
    delete(handles.layers(layer_index).label_handle,...
        handles.layers(layer_index).interface_handle,...
        handles.layers(layer_index).prop_lab_handle);
    handles.layers(layer_index) = [];
    
    handles.layers(layer_index).depth_to_top =                          ...
        sum([handles.layers(1:layer_index-1).thickness]);
    
       
    handles = update_model(handles);
    guidata(hObject, handles);
    update_layer_param(handles);
    handles = guidata(hObject);
    
    if ( ~isempty(handles.layers(layer_index).depth_to_top) )  &&       ...
            ( handles.layers(layer_index).depth_to_top ~= 0 )
        ylimits = [-1 2/5]*(9/7*handles.layers(end).depth_to_top);
        set(handles.axes1,'ylim',ylimits);
        
        if strcmp(handles.config.type,'TEM Central Loop')
            yscale = diff(ylimits);
            t = sin(0:pi/100:pi).*yscale./70;
            set(handles.config.plot_handle(1),'ydata',t.*4);
            set(handles.config.plot_handle(2),'ydata',t.*1);
        end
    end
    handles = update_model(handles);
    % Update handles structure
    guidata(hObject, handles);
end


% --------------------------------------------------------------------
function Extra_menu_Callback(hObject, eventdata, handles)
% hObject    handle to Untitled_1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if getappdata(0, 'compiled')
    disp('CR1Dmod:Extra_menu_Callback: Keyboard access...');
    keyboard
end


% --------------------------------------------------------------------
function Tx_side_edit_Callback(hObject, eventdata, handles)

[num,isOK] = str2num(get(hObject,'String'));
if isOK && isfinite(num(1))
    handles.config.TxS = num(1);
    handles.config.TxR = sqrt(handles.config.TxS.^2/pi);
end
set(hObject,'String',num2str(handles.config.TxS));

handles = update_config(handles);
handles = update_model(handles);
guidata(hObject, handles);


% --------------------------------------------------------------------
function Rx_area_edit_Callback(hObject, eventdata, handles)

[num,isOK] = str2num(get(hObject,'String'));
if isOK && isfinite(num(1))
    handles.config.RxA = num(1);
end
set(hObject,'String',num2str(handles.config.RxA));

handles = update_config(handles);
handles = update_model(handles);
guidata(hObject, handles);


% --------------------------------------------------------------------
function layer_label_Callback(hObject, eventdata, layerNo)

handles = guidata(hObject);
set(handles.Layer_popup, 'Value', layerNo);
Layer_popup_Callback(handles.Layer_popup, [], handles);


% --------------------------------------------------------------------
% --- Executes during object creation, after setting all properties.
function Layer_popup_CreateFcn(hObject, eventdata, handles)

if ispc
    set(hObject,'BackgroundColor','white');
else
    set(hObject,'BackgroundColor',get(0,'defaultUicontrolBackgroundColor'));
end

% --------------------------------------------------------------------
% --- Executes during object creation, after setting all properties.
function h_edit_CreateFcn(hObject, eventdata, handles)

if ispc
    set(hObject,'BackgroundColor','white');
else
    set(hObject,'BackgroundColor',get(0,'defaultUicontrolBackgroundColor'));
end

% --------------------------------------------------------------------
% --- Executes during object creation, after setting all properties.
function DC_res_edit_CreateFcn(hObject, eventdata, handles)

if ispc
    set(hObject,'BackgroundColor','white');
else
    set(hObject,'BackgroundColor',get(0,'defaultUicontrolBackgroundColor'));
end

% --------------------------------------------------------------------
% --- Executes during object creation, after setting all properties.
function m_edit_CreateFcn(hObject, eventdata, handles)

if ispc
    set(hObject,'BackgroundColor','white');
else
    set(hObject,'BackgroundColor',get(0,'defaultUicontrolBackgroundColor'));
end

% --------------------------------------------------------------------
% --- Executes during object creation, after setting all properties.
function Tau_edit_CreateFcn(hObject, eventdata, handles)

if ispc
    set(hObject,'BackgroundColor','white');
else
    set(hObject,'BackgroundColor',get(0,'defaultUicontrolBackgroundColor'));
end

% --------------------------------------------------------------------
% --- Executes during object creation, after setting all properties.
function c_edit_CreateFcn(hObject, eventdata, handles)

if ispc
    set(hObject,'BackgroundColor','white');
else
    set(hObject,'BackgroundColor',get(0,'defaultUicontrolBackgroundColor'));
end

% --------------------------------------------------------------------
% --- Executes during object creation, after setting all properties.
function Eps_r_edit_CreateFcn(hObject, eventdata, handles)

if ispc
    set(hObject,'BackgroundColor','white');
else
    set(hObject,'BackgroundColor',get(0,'defaultUicontrolBackgroundColor'));
end

% --------------------------------------------------------------------
% --- Executes during object creation, after setting all properties.
function Mu_edit_CreateFcn(hObject, eventdata, handles)

if ispc
    set(hObject,'BackgroundColor','white');
else
    set(hObject,'BackgroundColor',get(0,'defaultUicontrolBackgroundColor'));
end

% --------------------------------------------------------------------
% --- Executes during object creation, after setting all properties.
function Config_popup_CreateFcn(hObject, eventdata, handles)

if ispc
    set(hObject,'BackgroundColor','white');
else
    set(hObject,'BackgroundColor',get(0,'defaultUicontrolBackgroundColor'));
end

% --------------------------------------------------------------------
% --- Executes during object creation, after setting all properties.
function Aspac_edit_CreateFcn(hObject, eventdata, handles)

if ispc
    set(hObject,'BackgroundColor','white');
else
    set(hObject,'BackgroundColor',get(0,'defaultUicontrolBackgroundColor'));
end

% --------------------------------------------------------------------
% --- Executes during object creation, after setting all properties.
function Nspac_edit_CreateFcn(hObject, eventdata, handles)

if ispc
    set(hObject,'BackgroundColor','white');
else
    set(hObject,'BackgroundColor',get(0,'defaultUicontrolBackgroundColor'));
end

% --------------------------------------------------------------------
% --- Executes during object creation, after setting all properties.
function OA_edit_CreateFcn(hObject, eventdata, handles)

if ispc
    set(hObject,'BackgroundColor','white');
else
    set(hObject,'BackgroundColor',get(0,'defaultUicontrolBackgroundColor'));
end

% --------------------------------------------------------------------
% --- Executes during object creation, after setting all properties.
function OM_edit_CreateFcn(hObject, eventdata, handles)

if ispc
    set(hObject,'BackgroundColor','white');
else
    set(hObject,'BackgroundColor',get(0,'defaultUicontrolBackgroundColor'));
end

% --------------------------------------------------------------------
% --- Executes during object creation, after setting all properties.
function Rspac_edit_CreateFcn(hObject, eventdata, handles)

if ispc
    set(hObject,'BackgroundColor','white');
else
    set(hObject,'BackgroundColor',get(0,'defaultUicontrolBackgroundColor'));
end

% --------------------------------------------------------------------
% --- Executes during object creation, after setting all properties.
function Tx_side_edit_CreateFcn(hObject, eventdata, handles)

if ispc
    set(hObject,'BackgroundColor','white');
else
    set(hObject,'BackgroundColor',get(0,'defaultUicontrolBackgroundColor'));
end

% --------------------------------------------------------------------
% --- Executes during object creation, after setting all properties.
function Rx_area_edit_CreateFcn(hObject, eventdata, handles)

if ispc
    set(hObject,'BackgroundColor','white');
else
    set(hObject,'BackgroundColor',get(0,'defaultUicontrolBackgroundColor'));
end


% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure

if isappdata(0,'debug') && getappdata(0,'debug')
    disp('Executing CR1Dmod::figure1_CloseRequestFcn');
end

if isfield(handles,'compute_win') &&                                    ...
        ishandle(handles.compute_win)
    delete(handles.compute_win);
end

if handles.mfilePathRemove
    rmpath(handles.mfilePath);
end

delete(hObject);


% --------------------------------------------------------------------
function Keyboard_menu_Callback(hObject, eventdata, handles)
% hObject    handle to Untitled_1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
disp('Type return to resume CR1Dmod operation.')
keyboard

