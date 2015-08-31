function depths_pred = getDepth_Fayao(img_data)

varargin={};
run( '~/externals/depth-fayao/libs/vlfeat-0.9.18/toolbox/vl_setup');
dir_matConvNet='~/externals/depth-fayao/libs/matconvnet_20141015/matlab/';
addpath(genpath(dir_matConvNet));
run([dir_matConvNet 'vl_setupnn.m']);

opts=[];

% % some indoor image examples:
img_dir='~/externals/depth-fayao/custom_indoor_sample/'; 
%img_dir='~/mbluser/summer_vision_lang_2/optical_flow/videos';
img_type='indoor';

%folder for saving prediction results
[tmp_dir, img_dir_name]=fileparts(img_dir);
if isempty(img_dir_name)
    [~, img_dir_name]=fileparts(tmp_dir);
end
result_dir=fullfile('~/externals/depth-fayao', 'results', img_dir_name);

ds_config=[];
%settings we used for training our model:
% 1. sp_size: average superpixel size in SLIC 
% 2. max_img_edge: resize the image with the largest edge <= max_img_edge
if strcmp(img_type, 'outdoor') 
    ds_config.sp_size=16;
    ds_config.max_img_edge=600; 
    
    %outdoor scene model
    trained_model_file='~/externals/depth-fayao/model_trained/model_dcnf-fcsp_Make3D'; 
end

if strcmp(img_type, 'indoor')
    ds_config.sp_size=20; 
    ds_config.max_img_edge=640; 
    
    %indoor scene model
    trained_model_file='~/externals/depth-fayao/model_trained/model_dcnf-fcsp_NYUD2';   
end

% opts.useGpu=false;
opts.useGpu=true;

if opts.useGpu
    if gpuDeviceCount==0
        disp('no GPU found!');
        opts.useGpu=false;
    end
end

opts = vl_argparse(opts, varargin) ;

fprintf('\nloading trained model...\n\n');

model_trained=load(trained_model_file); 
model_trained=model_trained.data_obj;

opts_eval=[];
opts_eval.result_dir=result_dir;
opts_eval.useGpu = opts.useGpu;


%turn this on to show depths in log scale, better visulization for outdoor scenes
if strcmpi(img_type, 'indoor')
    opts_eval.do_show_log_scale=false; 
end

if strcmpi(img_type, 'outdoor')
    opts_eval.do_show_log_scale=true; 
end



% file_infos=dir(fullfile(img_dir,'*'));
% valid_file_flags=true(length(file_infos), 1);
% for f_idx=1:length(file_infos)
%     if file_infos(f_idx).isdir
%         valid_file_flags(f_idx)=false;
%     end
% end
% file_infos=file_infos(valid_file_flags);
% 
% img_num=length(file_infos);
% 
% if img_num==0
%     error('Error! no test images found!');
% end
% 
% for img_idx=1:img_num
%     
%     one_f_info=file_infos(img_idx);
%     one_img_file=one_f_info.name;
%     full_img_file=fullfile(img_dir, one_img_file);
% 
%     fprintf('\n-------------------------------------------\n');
%     fprintf('processing image (%d of %d): %s\n', img_idx, img_num, full_img_file);
% 
%    img_data=read_img_rgb(full_img_file);

    if ~isempty(ds_config.max_img_edge)
        max_img_edge=ds_config.max_img_edge;

        img_size1=size(img_data, 1);
        img_size2=size(img_data, 2);
        
        
        if img_size1>img_size2
            if img_size1>max_img_edge
                img_data=imresize(img_data, [max_img_edge, NaN]);
            end
        else
            if img_size2>max_img_edge
                img_data=imresize(img_data, [NaN, max_img_edge]);
            end
        end
    end


    fprintf('generating superpixels...\n');
    sp_info=gen_supperpixel_info(img_data, ds_config.sp_size);

    fprintf('generating pairwise info...\n');
    pws_info=gen_feature_info_pairwise(img_data, sp_info);


    ds_info=[];
    ds_info.img_idxes=1;
    ds_info.img_data=img_data;
    ds_info.sp_info{1}=sp_info;
    ds_info.pws_info=pws_info;
    ds_info.sp_num_imgs=sp_info.sp_num;

    
    depths_pred = do_model_evaluate(model_trained, ds_info, opts_eval);
    %% normalizing according to number of pixels per dimension
    %  so depth measurements will be in the same scale as x and y distances
    npixels_coefficient = mean(size(img_data,1),size(img_data,2));
    depths_pred = npixels_coefficient*depths_pred/mean(depths_pred(:));
    depths_pred = depths_pred.';

%     fprintf('inpaiting using Anat Levin`s colorization code, this may take a while...\n');
%     depths_inpaint = do_inpainting(depths_pred, img_data, sp_info);
% 
%     fprintf('saving prediction results in: %s\n', result_dir);
%     opts_eval.label_norm_info=model_trained.label_norm_info;
%     opts_eval.img_file_name=one_img_file;
%     do_save_prediction( depths_inpaint, opts_eval);

%     close all
    
% end
end














