/* Tiny consumer so size reports measure linked/stripped code, not .a bloat. */
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>
#include <stdio.h>

int main(void) {
    printf("avformat %s\n", av_version_info());
    printf("avcodec  %u\n", avcodec_version());
    printf("swscale  %u\n", swscale_version());
    /* Touch symbols that pull demuxer/decoder registration paths. */
    (void)av_find_input_format("mov");
    (void)av_find_input_format("matroska");
    (void)av_find_input_format("gif");
    (void)av_find_input_format("apng");
    (void)av_find_input_format("image2");
    /* Pipe demuxers register as "<fmt>_pipe"; configure names are image_<fmt>_pipe. */
    (void)av_find_input_format("jpeg_pipe");
    (void)av_find_input_format("png_pipe");
    (void)av_find_input_format("bmp_pipe");
    (void)av_find_input_format("webp_pipe");
    (void)avcodec_find_decoder(AV_CODEC_ID_H264);
    (void)avcodec_find_decoder(AV_CODEC_ID_VP8);
    (void)avcodec_find_decoder(AV_CODEC_ID_VP9);
    (void)avcodec_find_decoder(AV_CODEC_ID_AV1);
    (void)avcodec_find_decoder(AV_CODEC_ID_GIF);
    (void)avcodec_find_decoder(AV_CODEC_ID_WEBP);
    (void)avcodec_find_decoder(AV_CODEC_ID_APNG);
    (void)avcodec_find_decoder(AV_CODEC_ID_PNG);
    (void)avcodec_find_decoder(AV_CODEC_ID_MJPEG);
    (void)avcodec_find_decoder(AV_CODEC_ID_BMP);
    (void)avcodec_find_decoder(AV_CODEC_ID_TARGA);
    return 0;
}
