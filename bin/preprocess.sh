wd=${0%/*}
idx=0
bcores=1
cores=1
mh=10
mi=19
ma=25
cpm=1
norm=1000000
interTest='n'
interTest0='n'
# ----------> parameter capture start <------------
if [ "$#" -eq 0 ] ; then echo -e "type ${0##*/} -h for help message"
    exit 1
fi
if [ "$#" -gt 0 ]
    then
    for (( i=1; i<="$#"; i++ )) ; do
        case ${!i} in
            -h)	
echo "Help messeage:
    options: 
        # necessary options:
        -m:  string --  mode: r | c | m;
                        raw(mode): trim adaptor --> normalization --> length and abundance filter --> mapping
                        clean(mode): normalization --> length and abundance filter --> mapping
                        mapping(mode): mapping
        -i:  file   --  for r mode: fastq file or fastq.gz file
                         for c mode: fasta file or fasta.gz file
                         for m mode: length and abundance filter fasta file
        -r:  file   --  reference sequence fasta file
        -in: string --  index prefix, -r option will be ignored when -in enable
        -o:  outfile --  outfile name

        # options with default value
        -j:  int    --  adaptor trim parallel cores; <8 is recommend, only need in r mode, default=1
        -bj: int    --  bowtie parallel cores; defalut=1
        -mh: int    --  max hits when mapping to ref sequence, default=10
        -mi: int    --  minimal sRNA reads length cutoff, default=19
        -ma: int    --  maxmial sRNA reads length cutoff, default=25
        -e:  float  --  sRNA reads cpm cutoff, default=1 
        -n:  int    --  normalization base, default=1000000


        # other
        -v:         --  print version information
        -h:         --  print help information
        "
exit 1
;;
            -i)
                ((i+=1))
                inp=$(readlink -e ${!i})
                ;;
            -r)
                ((i+=1))
                ref=$(readlink -e ${!i})
                ;;
            -in)
                ((i+=1))
                index=${!i}
                idx=1
                ;;
            -m)
                ((i+=1))
                mode=${!i}
                ;;
            -j)
                ((i+=1))
                cores=${!i}
                ;;
            -bj)
                ((i+=1))
                bcores=${!i}
                ;;
            -mh)
                ((i+=1))
                mh=${!i}
                ;;
            -mi)
                ((i+=1))
                mi=${!i}
                ;;
            -ma)
                ((i+=1))
                ma=${!i}
                ;;
            -e)
                ((i+=1))
                cpm=${!i}
                ;;
            -n)
                ((i+=1))
                norm=${!i}
                ;;
            -o)
                ((i+=1))
                outfile_name=${!i}
                ;;
            -it)
                ((i+=1))
                interTest=${!i}
                ;;
            -ia)
                ((i+=1))
                interTest0=${!i}
                ;;
            *)
                echo "\"${!i}\" is not a valid parameter in ${0##*/}. See -h"
                exit 1
                ;;
        esac
    done
fi
# ----------> parameter capture end<------------
suffix=${inp##*\.}
tmp=${inp##*/}
id=${tmp%%.*}
if [ $mode = 'm' ]; then
    if [ $idx -eq 0 ]; then
        tmp=${ref##*/}
        refid=${tmp%.*}
        [ -e index ] || mkdir index
        bindex=index/${refid%.*}_index
        if [ -e ${bindex}.rev.1.ebwt ]; then
            echo "$ref index exsit, pass build index"
        else
            bowtie-build $ref $bindex
        fi
        if [ $outfile_name!='' ]; then
            bowtie -t -v 0 -p $bcores -f -m $mh -a $bindex $inp ${outfile_name}
        else
            bowtie -t -v 0 -p $bcores -f -m $mh -a $bindex $inp ${id}.map
        fi
    else
        bindex=$index
        if [ $outfile_name!='' ]; then
            bowtie -t -v 0 -p $bcores -f -m $mh -a $bindex $inp ${outfile_name}
        else
            bowtie -t -v 0 -p $bcores -f -m $mh -a $bindex $inp ${id}.map
        fi
    fi
else
    if [[ $inp =~ fastq\.gz$ ]] || [[ $inp =~ fq\.gz$ ]] || [[ $inp =~ fq$ ]]; then
        if [ $mode = 'r' ]; then
            tmp=${inp##*/}
            id=${tmp%%.*}
            adaptor=`python3 $wd/dnapi.py $inp`
            echo "the adaptor of ${inp##*/} is $adaptor"
            trim_galore --dont_gzip --stringency 3 --length $mi --max_length $ma -a $adaptor $inp -j $cores
            seqkit fq2fa ${id}_trimmed.fq > ${id}_trimmed.fa
            rm ${id}_trimmed.fq
            [ $interTest0 != 'y' ] || exit
            python3 $wd/format.py -i ${id}_trimmed.fa -o ${id}_trimmed_format.fa -it f -ot fn -of $id -n $norm
            rm ${id}_trimmed.fa
            python3 $wd/filter.py -i ${id}_trimmed_format.fa -o ${id}_trimmed_format_filter.fa -min $mi -max $ma -count $cpm
            [ $interTest != 'y' ] || exit
            rm ${id}_trimmed_format.fa
            if [ $idx -eq 0 ]; then
                tmp=${ref##*/}
                refid=${tmp%.*}
                [ -e index ] || mkdir index
                bindex=index/${refid%.*}_index
                if [ -e ${bindex}.rev.1.ebwt ]; then
                    echo "$ref index exsit, pass build index"
                else
                    bowtie-build $ref $bindex
                fi
                if [ $outfile_name!='' ]; then
                    bowtie -t -v 0 -p $bcores -f -m $mh -a $bindex ${id}_trimmed_format_filter.fa ${outfile_name}
                else
                    bowtie -t -v 0 -p $bcores -f -m $mh -a $bindex ${id}_trimmed_format_filter.fa ${id}_trimmed_format_filter.map
                fi
            else
                bindex=$index
                if [ $outfile_name!='' ]; then
                    bowtie -t -v 0 -p $bcores -f -m $mh -a $bindex ${id}_trimmed_format_filter.fa ${outfile_name}
                else
                    bowtie -t -v 0 -p $bcores -f -m $mh -a $bindex ${id}_trimmed_format_filter.fa ${id}_trimmed_format_filter.map
                fi
            fi
        elif [ $mode = 'c' ]; then
            tmp=${inp##*/}
            id=${tmp%%.*}
            seqkit fq2fa $inp > ${id}_trimmed.fa
            python3 $wd/format.py -i ${id}_trimmed.fa -o ${id}_trimmed_format.fa -it f -ot fn -of $id -n $norm
            rm ${id}_trimmed.fa
            python3 $wd/filter.py -i ${id}_trimmed_format.fa -o ${id}_trimmed_format_filter.fa -min $mi -max $ma -count $cpm
            rm ${id}_trimmed_format.fa
            if [ $idx -eq 0 ]; then
                tmp=${ref##*/}
                refid=${tmp%.*}
                [ -e index ] || mkdir index
                bindex=index/${refid%.*}_index
                if [ -e ${bindex}.rev.1.ebwt ]; then
                    echo "$ref index exsit, pass build index"
                else
                    bowtie-build $ref $bindex
                fi
                if [ $outfile_name!='' ]; then
                    bowtie -t -v 0 -p $bcores -f -m $mh -a $bindex ${id}_trimmed_format_filter.fa ${outfile_name}
                else
                    bowtie -t -v 0 -p $bcores -f -m $mh -a $bindex ${id}_trimmed_format_filter.fa ${id}_trimmed_format_filter.map
                fi
            else
                bindex=$index
                if [ $outfile_name!='' ]; then
                    bowtie -t -v 0 -p $bcores -f -m $mh -a $bindex ${id}_trimmed_format_filter.fa ${outfile_name}
                else
                    bowtie -t -v 0 -p $bcores -f -m $mh -a $bindex ${id}_trimmed_format_filter.fa ${id}_trimmed_format_filter.map
                fi
            fi
        else
            echo please input correct mode: r or c
        fi
    elif [[ $inp =~ fasta\.gz$ ]] || [[ $inp =~ fa\.gz$ ]] || [[ $inp =~ fa$ ]]; then
        if [ $mode = 'r' ]; then
            echo fasta file is not support to trim adaptor in this version
        elif [ $mode = 'c' ]; then
            tmp=${inp##*/}
            id=${tmp%%.*}
            python3 $wd/format.py -i $inp -o ${id}_trimmed_format.fa -it f -ot fn -of $id -n $norm
            python3 $wd/filter.py -i ${id}_trimmed_format.fa -o ${id}_trimmed_format_filter.fa -min $mi -max $ma -count $cpm
            rm ${id}_trimmed_format.fa
            if [ $idx -eq 0 ]; then
                tmp=${ref##*/}
                refid=${tmp%.*}
                [ -e index ] || mkdir index
                bindex=index/${refid%.*}_index
                if [ -e ${bindex}.rev.1.ebwt ]; then
                    echo "$ref index exsit, pass build index"
                else
                    bowtie-build $ref $bindex
                fi
                if [ $outfile_name!='' ]; then
                    bowtie -t -v 0 -p $bcores -f -m $mh -a $bindex ${id}_trimmed_format_filter.fa ${outfile_name}
                else
                    bowtie -t -v 0 -p $bcores -f -m $mh -a $bindex ${id}_trimmed_format_filter.fa ${id}_trimmed_format_filter.map
                fi
            else
                bindex=$index
                if [ $outfile_name!='' ]; then
                    bowtie -t -v 0 -p $bcores -f -m $mh -a $bindex ${id}_trimmed_format_filter.fa ${outfile_name}
                else
                    bowtie -t -v 0 -p $bcores -f -m $mh -a $bindex ${id}_trimmed_format_filter.fa ${id}_trimmed_format_filter.map
                fi
            fi
        else
            echo please input correct mode: r or c
        fi
    else
        echo please input correct file, fasta or fastq
    fi
fi
