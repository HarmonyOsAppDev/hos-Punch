import { weekKeyMap } from '../constants';
import { SelectDateType } from '../types';

export function getDaysOfMonthWithFirstDayOfWeek({year, month}: SelectDateType ) {
  // 计算该月总天数
  const totalDays = getDaysInMonth(year, month);

  // 生成从1到总天数的数组
  const daysArray = Array.from({ length: totalDays }, (_, index) => index + 1);

  // 计算当月1号是星期几，返回值0-6分别对应周日到周六
  const firstDayOfWeek = Math.ceil(calculateFirstDayOfMonth(year, month));

  // 返回包含天数数组以及1号星期几的数组
  return { daysArray, firstDayOfWeek };
}

// 计算指定年月1号是星期几的函数
function calculateFirstDayOfMonth(year, month) {
  if (month < 3) {
    month += 12;
    year--;
  }
  const century = Math.floor(year / 100);
  const yearInCentury = year % 100;
  const weekDay = (dayOfYear(year, month, 1) + century / 4 - century * 2 + yearInCentury + yearInCentury / 4 + 5) % 7;
  return (weekDay + 7) % 7; // 确保返回值为0-6，0表示周日
}

// 计算一年中某一天的序号（即一年中的第几天）
function dayOfYear(year, month, day) {
  let sum = 0;
  for (let i = 1; i < month; i++) {
    sum += getDaysInMonth(year, i);
  }
  sum += day;
  return sum;
}

// 原始的getDaysInMonth函数保持不变
function getDaysInMonth(year, month) {
  month -= 1; // 调整月份
  const isLeapYear = year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
  return [
    31,
    isLeapYear ? 29 : 28,
    31, 30, 31, 30,
    31, 31, 30, 31,
    30, 31
  ][month];
}


export function getYMD(time?: number) {
  const now = time ? time : new Date().getTime();
  const r =  {
    year: new Date(now).getFullYear(),
    month: new Date(now).getMonth() + 1,
    day: new Date(now).getDate(),
    hour: new Date(now).getHours(),
    minute: new Date(now).getMinutes(),
  };

  return {
    year_month_day: r,
    dateStr: `${r.year}-${r.month}-${r.day}`,
    dateStrHHMM: `${r.year}-${r.month}-${r.day} ${r.hour}: ${r.minute}`,
  }
}


export function getEndTimeInit(startTime?: number) {
    let now = startTime ? startTime : new Date().getTime();
    now += 30 * 24 * 60 * 60 * 1000; // 时间加一个月
    const r =  {
      year: new Date(now).getFullYear(),
      month: new Date(now).getMonth() + 1,
      day: new Date(now).getDate(),
    };
    return {
      originFormat: new Date(now),
      dateStr:`${r.year}-${r.month}-${r.day}`
    }
}

export const weekDayChangeStr = (numArr: number[]) => {
  if (numArr.length > 0) {
    let str = `周`;
    numArr.map((item, index) => {
      str += `${weekKeyMap[String(item)]}${index !== numArr.length - 1 ? ',' : ''}`;
    });
    return str;
  } else {
    return `没有选择周期`
  }
}

export const monthChangeStr = (numArr: number[]) => {
  if (numArr.length > 0) {
    let str = ``;
    let tmpArr = numArr;
    if (numArr.length > 9) {
      tmpArr = tmpArr.slice(0, 9);
      tmpArr.map((item, index) => {
        str += `${item}${index !== tmpArr.length - 1 ? ',' : '...'}`;
      });
    } else {
      tmpArr.map((item, index) => {
        str += `${item}${index !== tmpArr.length - 1 ? ',' : ''}`;
      });
    }

    return str;
  } else {
    return `没有选择周期`
  }
}


export function isObjectEqual(obj1, obj2) {
  // 如果两者引用同一对象或者都是null，则它们相等
  if (obj1 === obj2) return true;

  // 如果两者之一为null或不是对象，则它们不相等
  if (obj1 == null || typeof obj1 !== 'object' ||
    obj2 == null || typeof obj2 !== 'object') {
    return false;
  }

  // 获取obj1的所有属性名
  const keys1 = Object.keys(obj1);
  // 获取obj2的所有属性名
  const keys2 = Object.keys(obj2);

  // 如果属性数量不同，则对象不相等
  if (keys1.length !== keys2.length) {
    return false;
  }

  // 遍历所有属性，进行深度比较
  for (let key of keys1) {
    if (!keys2.includes(key) || !isObjectEqual(obj1[key], obj2[key])) {
      return false;
    }
  }

  return true;
}



