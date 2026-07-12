/* Tiny consumer so size reports measure linked/stripped code, not .a bloat. */
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>
#include <stdio.h>

int main(void) {
    printf("avformat %s\n", av_version_info());
    printf("avcodec  %u\n", avcodec_version());
    printf("swscale  %u\n", swscale_version());
    /* Touch symbols that pull decoder/demux registration paths. */
    (void)av_find_input_format("mov");
    (void)av_find_input_format("matroska");
    (void)avcodec_find_decoder(AV_CODEC_ID_H264);
    (void)avcodec_find_decoder(AV_CODEC_ID_VP8);
    (void)avcodec_find_decoder(AV_CODEC_ID_VP9);
    return 0;
}
