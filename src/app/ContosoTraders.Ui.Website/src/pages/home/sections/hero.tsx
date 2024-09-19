import { HeroBG, HeroBG2, LocalMallIcon } from "app/assets/images";
import Corousel from "app/components/corousel/corousel";
import { useNavigate } from "react-router-dom";

function Hero() {

        const history = useNavigate();
        const buyNow = (id:number):void => {
            history('/product/detail/'+id);
        }
        const moreDetails = ():void => {
            history('/list/controllers');
        }
        const ITEMS = [
            {
                name: "The Fastest, Most Powerful Xbox Ever.",
                description: "Elevate your game with the all-new Xbox Wireless Controller - Lunar Shift Special Edition",
                bg: HeroBG,
                buttons : [
                    {
                        title : 'Buy Now',
                        color : 'primary',
                        class : 'BannerButton1',
                        endIcon: <img src={LocalMallIcon} width={25} height='auto' alt=""/>,
                        onClickFn : () => buyNow(1)
                    },
                    {
                        title : 'More Details',
                        color : 'inherit',
                        class : 'BannerButton2',
                        endIcon : '',
                        onClickFn : () => moreDetails()
                    }
                ]
            },
            {
                name: "Xbox Wireless Controller - Mineral Camo Special Edition",
                description: "Textured triggers and bumpers | Hybrid D-pad | Button mapping | Bluetooth® technology",
                bg: HeroBG2,
                buttons : [
                    {
                        title : 'Buy Now',
                        color : 'primary',
                        class : 'BannerButton1',
                        endIcon: <img src={LocalMallIcon} width={25} height='auto' alt=""/>,
                        onClickFn : () => buyNow(1)
                    },
                    {
                        title : 'More Details',
                        color : 'inherit',
                        class : 'BannerButton2',
                        endIcon : '',
                        onClickFn : () => moreDetails()
                    }
                ]
            },
        ];
        
        return (
            <div className="hero" data-testid="carousel">
                <Corousel items={ITEMS} />
            </div>
        );
}

export default Hero;
